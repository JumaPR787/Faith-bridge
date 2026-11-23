import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/audio_capture.dart';
import '../../data/live_connection.dart';
import '../../domain/models.dart';
import '../../domain/transcript_store.dart';

enum LivePhase { idle, requestingPermission, connecting, live, paused, reconnecting, ending, ended, error }

enum PauseReason { user, background, interruption }

/// Orquesta micrófono → conexión → subtítulos en la pantalla en vivo.
class LiveController extends ChangeNotifier with WidgetsBindingObserver {
  LiveController({
    required this.audio,
    required this.connectionFactory,
    required this.source,
    required this.target,
    required this.save,
    required this.keepScreenOn,
    this.onUsage,
  }) : store = TranscriptStore(translationEnabled: target != null);

  final AudioSource audio;
  final LiveConnection Function(LiveStartParams params, int Function() lastSeq) connectionFactory;
  final Lang source;
  final Lang? target;
  final bool save;
  final bool keepScreenOn;
  final void Function(int remainingSeconds)? onUsage;
  final TranscriptStore store;

  LivePhase phase = LivePhase.idle;
  PauseReason? pauseReason;
  String? errorCode;
  String? endedReason;
  String? transcriptId;
  bool quotaWarning = false;

  /// El servidor informa si usa proveedores simulados (solo desarrollo).
  bool simulated = false;
  int sessionSeconds = 0;
  int remainingSeconds = 0;

  LiveConnection? _conn;
  StreamSubscription<Uint8List>? _audioSub;
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  StreamSubscription<ConnState>? _stateSub;
  StreamSubscription<void>? _intSub;
  Timer? _ticker;
  bool _disposed = false;

  bool get micActive => phase == LivePhase.live || phase == LivePhase.reconnecting;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Única vía para activar el micrófono: una acción explícita del usuario.
  Future<void> start() async {
    if (phase != LivePhase.idle && phase != LivePhase.error) return;
    errorCode = null;
    phase = LivePhase.requestingPermission;
    _notify();
    if (!await audio.ensurePermission()) {
      _fail('mic_denied');
      return;
    }
    phase = LivePhase.connecting;
    _notify();
    final conn = connectionFactory(
      LiveStartParams(sourceLang: source.code, targetLang: target?.code, saveTranscript: save),
      () => store.lastSeq,
    );
    _conn = conn;
    _eventSub = conn.events.listen(_onEvent);
    _stateSub = conn.states.listen((s) {
      if (s == ConnState.reconnecting && phase == LivePhase.live) {
        phase = LivePhase.reconnecting;
        _notify();
      } else if (s == ConnState.open && phase == LivePhase.reconnecting) {
        phase = LivePhase.live;
        _notify();
      }
    });
    try {
      final ready = await conn.connect();
      final q = ready['quota'] as Map<String, dynamic>;
      remainingSeconds = (q['remainingSeconds'] as num).toInt();
      simulated = ready['simulated'] == true;
    } on LiveError catch (e) {
      await _teardown();
      _fail(e.code);
      return;
    } catch (_) {
      await _teardown();
      _fail('network');
      return;
    }
    try {
      final stream = await audio.start();
      _audioSub = stream.listen((chunk) => _conn?.sendAudio(chunk));
      _intSub = audio.interruptions.listen((_) => pause(PauseReason.interruption));
    } catch (_) {
      await _conn?.close();
      await _teardown();
      _fail('mic_denied');
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    if (keepScreenOn) unawaited(WakelockPlus.enable().catchError((_) {}));
    phase = LivePhase.live;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (phase == LivePhase.live) {
        sessionSeconds++;
        if (remainingSeconds > 0) remainingSeconds--;
        _notify();
      }
    });
    _notify();
  }

  void _onEvent(Map<String, dynamic> e) {
    if (store.apply(e)) _notify();
    switch (e['type']) {
      case 'usage':
        sessionSeconds = (e['sessionSeconds'] as num).toInt();
        remainingSeconds = (e['remainingSeconds'] as num).toInt();
        onUsage?.call(remainingSeconds);
        _notify();
      case 'quota_warning':
        quotaWarning = true;
        _notify();
      case 'ended':
        endedReason = e['reason'] as String?;
        transcriptId = e['transcriptId'] as String?;
        final secs = (e['sessionSeconds'] as num?)?.toInt() ?? -1;
        if (secs >= 0) sessionSeconds = secs;
        unawaited(_finishLocal());
      case 'error':
        if (e['fatal'] == true && phase != LivePhase.ending) errorCode = e['code'] as String?;
    }
  }

  Future<void> pause(PauseReason reason) async {
    if (phase != LivePhase.live && phase != LivePhase.reconnecting) return;
    pauseReason = reason;
    phase = LivePhase.paused;
    _notify();
    await audio.pause();
    _conn?.control('pause');
  }

  Future<void> resume() async {
    if (phase != LivePhase.paused) return;
    pauseReason = null;
    _conn?.control('resume');
    await audio.resume();
    phase = _conn?.state == ConnState.reconnecting ? LivePhase.reconnecting : LivePhase.live;
    _notify();
  }

  Future<void> finish() async {
    if (phase == LivePhase.ending || phase == LivePhase.ended) return;
    phase = LivePhase.ending;
    _notify();
    await audio.stop();
    _conn?.control('stop');
    // Espera el evento "ended" del servidor (incluye si se guardó la transcripción).
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (phase != LivePhase.ended && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (phase != LivePhase.ended) await _finishLocal();
  }

  Future<void> _finishLocal() async {
    if (phase == LivePhase.ended) return;
    await audio.stop();
    await _teardown();
    phase = LivePhase.ended;
    _notify();
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    await _audioSub?.cancel();
    await _intSub?.cancel();
    await _stateSub?.cancel();
    await _eventSub?.cancel();
    _audioSub = null;
    final c = _conn;
    _conn = null;
    await c?.close();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable().catchError((_) {}));
  }

  void _fail(String code) {
    errorCode = code;
    phase = LivePhase.error;
    _notify();
  }

  /// iOS y Android no permiten (sin configuración adicional y revisión de la
  /// tienda) seguir captando audio en segundo plano: la sesión se pausa.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      unawaited(pause(PauseReason.background));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(audio.stop().catchError((_) {}));
    unawaited(_teardown());
    super.dispose();
  }
}
