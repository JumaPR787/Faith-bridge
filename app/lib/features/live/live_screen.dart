import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/account_controller.dart';
import '../../data/audio_capture.dart';
import '../../data/live_connection.dart';
import '../../data/settings_controller.dart';
import '../../domain/models.dart';
import '../../domain/transcript_store.dart';
import '../common.dart';
import 'live_controller.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key, required this.source, required this.display, required this.save, this.controller});
  final Lang source;
  final DisplayMode display;
  final bool save;

  /// Inyectable para pruebas de widgets.
  final LiveController? controller;

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late final LiveController _c;
  final _scroll = ScrollController();
  bool _autoScroll = true;

  Lang? get _target => widget.display == DisplayMode.original ? null : widget.source.other;

  @override
  void initState() {
    super.initState();
    final account = context.read<AccountController>();
    final settings = context.read<SettingsController>();
    _c = widget.controller ??
        LiveController(
          audio: MicrophoneSource(),
          connectionFactory: (params, lastSeq) => LiveConnection(
            uri: AppConfig.liveSocketUri,
            tokenProvider: account.auth.accessToken,
            params: params,
            lastSeq: lastSeq,
          ),
          source: widget.source,
          target: _target,
          save: widget.save,
          keepScreenOn: settings.keepScreenOn,
          onUsage: account.updateQuotaRemaining,
        );
    _c.addListener(_onChange);
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final atBottom = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 48;
    // Si el usuario sube para leer, se pausa el desplazamiento automático.
    if (_scroll.position.userScrollDirection != ScrollDirection.idle) {
      if (_autoScroll != atBottom) setState(() => _autoScroll = atBottom);
    }
  }

  void _onChange() {
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    if (_c.phase == LivePhase.ended) context.read<AccountController>().refresh();
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirmFinish() async {
    if (_c.phase == LivePhase.idle || _c.phase == LivePhase.ended || _c.phase == LivePhase.error) return true;
    final ok = await confirmDialog(context, S.of(context).t('finish_confirm'), confirmLabel: S.of(context).t('finish'));
    if (ok) await _c.finish();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsController>();
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        return PopScope(
          canPop: _c.phase == LivePhase.idle || _c.phase == LivePhase.ended || _c.phase == LivePhase.error,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmFinish() && context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(s.t('live_title')),
              actions: [
                IconButton(
                  tooltip: '${s.t('text_size')} −',
                  icon: const Icon(Icons.text_decrease),
                  onPressed: () => settings.setCaptionScale(settings.captionScale - 0.15),
                ),
                IconButton(
                  tooltip: '${s.t('text_size')} +',
                  icon: const Icon(Icons.text_increase),
                  onPressed: () => settings.setCaptionScale(settings.captionScale + 0.15),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(children: [
                _StatusBar(c: _c),
                if (_c.simulated)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade200,
                    padding: const EdgeInsets.all(4),
                    child: Text(s.t('simulated_badge'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 12)),
                  ),
                if (_c.phase == LivePhase.paused && _c.pauseReason != PauseReason.user)
                  _Banner(text: _c.pauseReason == PauseReason.background ? s.t('paused_background') : s.t('paused_interruption')),
                if (_c.phase == LivePhase.reconnecting) _Banner(text: s.t('reconnecting')),
                if (_c.quotaWarning && _c.phase != LivePhase.ended) _Banner(text: s.t('quota_warning')),
                Expanded(child: _body(context, s, settings)),
                _Controls(c: _c, onFinish: _confirmFinish),
              ]),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: (!_autoScroll && _c.store.segments.isNotEmpty)
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 96),
                    child: FloatingActionButton.extended(
                      icon: const Icon(Icons.arrow_downward),
                      label: Text(s.t('jump_to_latest')),
                      onPressed: () {
                        setState(() => _autoScroll = true);
                        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                      },
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, S s, SettingsController settings) {
    final theme = Theme.of(context);
    switch (_c.phase) {
      case LivePhase.idle:
        return _IdleStart(onStart: _c.start);
      case LivePhase.requestingPermission:
      case LivePhase.connecting:
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(s.t('connecting'))]));
      case LivePhase.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(errorMessage(s, _c.errorCode), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 16),
              if (_c.errorCode == 'mic_denied') OutlinedButton(onPressed: openAppSettings, child: Text(s.t('open_settings'))),
              if (_c.errorCode == 'network' || _c.errorCode == 'stt_unavailable') FilledButton(onPressed: _c.start, child: Text(s.t('retry'))),
            ]),
          ),
        );
      default:
        break;
    }
    final segments = _c.store.segments;
    final interim = _c.store.interim;
    final scale = settings.captionScale;
    final base = theme.textTheme.headlineSmall!.copyWith(fontSize: 22 * scale, height: 1.35);
    final secondary = base.copyWith(fontSize: 18 * scale, color: theme.colorScheme.onSurfaceVariant);
    final showOriginal = widget.display != DisplayMode.translation;
    final showTranslation = widget.display != DisplayMode.original;

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isLast = i == segments.length - 1;
      final parts = <Widget>[];
      if (showTranslation) {
        final String text;
        final TextStyle style;
        switch (seg.translationState) {
          case TranslationState.ok:
            text = seg.translation!;
            style = base;
          case TranslationState.failed:
            text = s.t('translation_unavailable');
            style = secondary.copyWith(fontStyle: FontStyle.italic);
          case TranslationState.pending:
          case TranslationState.none:
            text = s.t('translating');
            style = secondary.copyWith(fontStyle: FontStyle.italic);
        }
        parts.add(Text(text, style: style));
      }
      if (showOriginal) {
        parts.add(Text(seg.text, style: showTranslation ? secondary : base));
      }
      children.add(Semantics(
        liveRegion: isLast,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts),
        ),
      ));
    }
    if (interim != null && showOriginal) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(interim, style: secondary.copyWith(fontStyle: FontStyle.italic)),
      ));
    }
    if (_c.phase == LivePhase.ended) {
      children.add(_EndedSummary(c: _c));
    }
    if (segments.isEmpty && interim == null && _c.phase != LivePhase.ended) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(s.t('listening'), textAlign: TextAlign.center, style: secondary)));
    }
    return ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: children);
  }
}

class _IdleStart extends StatelessWidget {
  const _IdleStart({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.t('ambient_notice'), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(icon: const Icon(Icons.mic), label: Text(s.t('start')), onPressed: onStart),
        ]),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.c});
  final LiveController c;
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final mic = c.micActive;
    final paused = c.phase == LivePhase.paused;
    final String conn = switch (c.phase) {
      LivePhase.live => s.t('connected'),
      LivePhase.reconnecting => s.t('reconnecting').split('(').first.trim(),
      LivePhase.connecting || LivePhase.requestingPermission => s.t('connecting'),
      LivePhase.paused => s.t('mic_paused'),
      _ => '',
    };
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        // Indicador visible de uso del micrófono.
        Semantics(
          label: mic ? s.t('mic_on') : s.t('mic_paused'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: mic ? Colors.red.shade700 : theme.colorScheme.outline, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(mic ? Icons.mic : Icons.mic_off, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(mic ? s.t('mic_on') : (paused ? s.t('mic_paused') : '—'), style: const TextStyle(color: Colors.white, fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(conn, overflow: TextOverflow.ellipsis)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${s.t('elapsed')}: ${formatClock(c.sessionSeconds)}', style: theme.textTheme.bodySmall),
          Text('${s.t('remaining')}: ${formatMinutes(c.remainingSeconds)}', style: theme.textTheme.bodySmall),
        ]),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.tertiaryContainer,
          padding: const EdgeInsets.all(12),
          child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer)),
        ),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.c, required this.onFinish});
  final LiveController c;
  final Future<bool> Function() onFinish;
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final active = c.phase == LivePhase.live || c.phase == LivePhase.reconnecting || c.phase == LivePhase.paused;
    if (!active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(children: [
        Expanded(
          child: c.phase == LivePhase.paused
              ? FilledButton.icon(icon: const Icon(Icons.play_arrow), label: Text(s.t('resume')), onPressed: c.resume)
              : OutlinedButton.icon(icon: const Icon(Icons.pause), label: Text(s.t('pause')), onPressed: () => c.pause(PauseReason.user)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError),
            icon: const Icon(Icons.stop),
            label: Text(s.t('finish')),
            onPressed: onFinish,
          ),
        ),
      ]),
    );
  }
}

class _EndedSummary extends StatelessWidget {
  const _EndedSummary({required this.c});
  final LiveController c;
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final msg = switch (c.endedReason) {
      'quota_exhausted' => s.t('ended_quota'),
      'max_duration' => s.t('ended_max_duration'),
      'superseded' => s.t('ended_superseded'),
      'stt_unavailable' => s.t('ended_stt'),
      'client_gone' => s.t('error_network'),
      _ => s.t('ended_ok'),
    };
    final text = c.store.toPlainText(includeOriginal: true, includeTranslation: true);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg, style: Theme.of(context).textTheme.titleMedium),
          Text('${s.t('elapsed')}: ${formatClock(c.sessionSeconds)}'),
          if (c.transcriptId != null) Text(s.t('saved_in_history')),
          const SizedBox(height: 8),
          if (text.isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(s.t('copy')),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) showSnack(context, s.t('copied'));
              },
            ),
        ]),
      ),
    );
  }
}
