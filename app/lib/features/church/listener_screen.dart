import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/listen_connection.dart';
import '../../data/live_connection.dart' show ChannelFactory;
import '../../data/settings_controller.dart';
import '../../domain/models.dart';
import '../../domain/transcript_store.dart';
import '../live/captions_view.dart';

enum ListenerPhase { connecting, waiting, live, interrupted, ended, error }

/// Estado de un asistente: solo recibe eventos; nunca usa el micrófono.
class ListenerController extends ChangeNotifier {
  ListenerController({required this.token, required bool translation, this.channelFactory, this.keepScreenOn = true})
      : store = TranscriptStore(translationEnabled: translation);

  final String token;
  final ChannelFactory? channelFactory;
  final bool keepScreenOn;
  final TranscriptStore store;
  ListenerPhase phase = ListenerPhase.connecting;
  String? errorCode;
  ListenConnection? _conn;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    final c = ListenConnection(uri: AppConfig.listenSocketUri, token: token, lastSeq: () => store.lastSeq, channelFactory: channelFactory);
    _conn = c;
    _sub = c.events.listen(_onEvent);
    if (keepScreenOn) unawaited(WakelockPlus.enable().catchError((_) {}));
    try {
      await c.connect();
    } catch (_) {
      phase = ListenerPhase.error;
      errorCode = 'network';
      _notify();
    }
  }

  void _onEvent(Map<String, dynamic> e) {
    store.apply(e);
    switch (e['type']) {
      case 'joined':
        phase = e['broadcasting'] == true ? ListenerPhase.live : ListenerPhase.waiting;
      case 'waiting':
        phase = ListenerPhase.waiting;
      case 'broadcast_interrupted':
        phase = ListenerPhase.interrupted;
      case 'segment':
      case 'interim':
      case 'translation':
        phase = ListenerPhase.live;
      case 'provider_status':
        if (phase != ListenerPhase.ended) phase = ListenerPhase.live;
      case 'ended':
        phase = ListenerPhase.ended;
        unawaited(WakelockPlus.disable().catchError((_) {}));
      case 'error':
        if (e['fatal'] == true) {
          phase = ListenerPhase.error;
          errorCode = e['code'] as String?;
        }
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    unawaited(_conn?.close());
    unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }
}

class ListenerScreen extends StatefulWidget {
  const ListenerScreen({super.key, required this.join, this.controller});

  /// Respuesta de POST /v1/church/join.
  final Map<String, dynamic> join;
  final ListenerController? controller;

  @override
  State<ListenerScreen> createState() => _ListenerScreenState();
}

class _ListenerScreenState extends State<ListenerScreen> {
  late final ListenerController _c;
  final _scroll = ScrollController();
  late DisplayMode _display;

  bool get _hasTranslation => widget.join['targetLang'] != null;

  @override
  void initState() {
    super.initState();
    _display = _hasTranslation ? DisplayMode.both : DisplayMode.original;
    _c = widget.controller ??
        ListenerController(token: widget.join['token'] as String, translation: _hasTranslation, keepScreenOn: context.read<SettingsController>().keepScreenOn);
    _c.addListener(_follow);
    unawaited(_c.start());
  }

  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _c.removeListener(_follow);
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsController>();
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final String? banner = switch (_c.phase) {
          ListenerPhase.connecting => s.t('connecting'),
          ListenerPhase.waiting => s.t('listener_waiting'),
          ListenerPhase.interrupted => s.t('listener_interrupted'),
          ListenerPhase.ended => s.t('listener_ended'),
          ListenerPhase.error => _c.errorCode == 'session_full' ? s.t('join_session_full') : _c.errorCode == 'session_ended' ? s.t('listener_ended') : s.t('error_network'),
          ListenerPhase.live => null,
        };
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.join['orgName'] as String? ?? s.t('church_title')),
            actions: [
              IconButton(tooltip: '${s.t('text_size')} −', icon: const Icon(Icons.text_decrease), onPressed: () => settings.setCaptionScale(settings.captionScale - 0.15)),
              IconButton(tooltip: '${s.t('text_size')} +', icon: const Icon(Icons.text_increase), onPressed: () => settings.setCaptionScale(settings.captionScale + 0.15)),
            ],
          ),
          body: SafeArea(
            child: Column(children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.mic_off, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.t('listener_no_mic'))),
                ]),
              ),
              if (banner != null)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    padding: const EdgeInsets.all(12),
                    child: Text(banner, style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer)),
                  ),
                ),
              if (_hasTranslation)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SegmentedButton<DisplayMode>(
                    segments: [
                      ButtonSegment(value: DisplayMode.translation, label: Text(s.t('show_translation'))),
                      ButtonSegment(value: DisplayMode.both, label: Text(s.t('show_both'))),
                    ],
                    selected: {_display},
                    onSelectionChanged: (v) => setState(() => _display = v.first),
                  ),
                ),
              Expanded(
                child: CaptionsView(
                  store: _c.store,
                  display: _display,
                  scale: settings.captionScale,
                  controller: _scroll,
                  emptyText: banner ?? s.t('listening'),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}
