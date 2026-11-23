import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Fuente de audio abstracta (sustituible en pruebas).
abstract class AudioSource {
  Future<bool> ensurePermission();
  Future<Stream<Uint8List>> start();
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();

  /// Se emite cuando el sistema pausa la captura (llamada, otra app de audio).
  Stream<void> get interruptions;
}

/// Micrófono del teléfono → PCM 16 bits, 16 kHz, mono (lo que espera el backend).
class MicrophoneSource implements AudioSource {
  final AudioRecorder _rec = AudioRecorder();
  final _interruptions = StreamController<void>.broadcast();
  StreamSubscription<RecordState>? _stateSub;
  bool _pausedByUs = false;

  @override
  Stream<void> get interruptions => _interruptions.stream;

  /// Solicita el permiso JUSTO antes de usar el micrófono.
  @override
  Future<bool> ensurePermission() => _rec.hasPermission(request: true);

  @override
  Future<Stream<Uint8List>> start() async {
    _pausedByUs = false;
    final stream = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      echoCancel: false,
      noiseSuppress: false,
      // Ante una llamada el sistema pausa; reanudar requiere acción del usuario.
      audioInterruption: AudioInterruptionMode.pause,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.mic),
    ));
    _stateSub ??= _rec.onStateChanged().listen((s) {
      if (s == RecordState.pause && !_pausedByUs) _interruptions.add(null);
    });
    return stream;
  }

  @override
  Future<void> pause() async {
    _pausedByUs = true;
    if (await _rec.isRecording()) await _rec.pause();
  }

  @override
  Future<void> resume() async {
    _pausedByUs = false;
    if (await _rec.isPaused()) await _rec.resume();
  }

  @override
  Future<void> stop() async {
    _pausedByUs = true;
    await _stateSub?.cancel();
    _stateSub = null;
    await _rec.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _rec.dispose();
    await _interruptions.close();
  }
}
