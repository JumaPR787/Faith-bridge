import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnState { idle, connecting, open, reconnecting, closed }

class LiveStartParams {
  LiveStartParams({required this.sourceLang, required this.targetLang, required this.saveTranscript, this.churchSessionId});
  final String sourceLang;
  final String? targetLang;
  final bool saveTranscript;

  /// Si existe, el teléfono transmite para una sesión del modo iglesia.
  final String? churchSessionId;
}

typedef ChannelFactory = WebSocketChannel Function(Uri uri);

/// Cliente del protocolo en vivo del backend (versión 1).
///
/// - El token va en el primer mensaje, no en la URL.
/// - Si la red se corta, reintenta con espera creciente y REANUDA la misma
///   sesión pidiendo solo los segmentos posteriores al último recibido.
/// - Mientras no hay conexión guarda como máximo [maxBufferedBytes] de audio
///   (≈5 s) y descarta lo más antiguo: nunca acumula audio sin límite.
class LiveConnection {
  LiveConnection({
    required this.uri,
    required this.tokenProvider,
    required this.params,
    required this.lastSeq,
    ChannelFactory? channelFactory,
    this.retryDelays = const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8), Duration(seconds: 16)],
    this.maxBufferedBytes = 16000 * 2 * 5,
  }) : _factory = channelFactory ?? ((u) => WebSocketChannel.connect(u));

  final Uri uri;
  final Future<String?> Function() tokenProvider;
  final LiveStartParams params;
  final int Function() lastSeq;
  final List<Duration> retryDelays;
  final int maxBufferedBytes;
  final ChannelFactory _factory;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _stateCtl = StreamController<ConnState>.broadcast();
  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;
  ConnState _state = ConnState.idle;
  String? sessionId;
  bool _closing = false;
  bool _fatal = false;
  final List<Uint8List> _buffer = [];
  int _bufferedBytes = 0;
  int droppedBytes = 0;

  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<ConnState> get states => _stateCtl.stream;
  ConnState get state => _state;

  void _setState(ConnState s) {
    _state = s;
    if (!_stateCtl.isClosed) _stateCtl.add(s);
  }

  /// Abre la sesión. Completa con el evento "ready" o lanza con el código de error.
  Future<Map<String, dynamic>> connect() async {
    _setState(ConnState.connecting);
    return _open(resume: false);
  }

  Future<Map<String, dynamic>> _open({required bool resume}) async {
    final token = await tokenProvider();
    if (token == null) throw const LiveError('unauthorized');
    final ch = _factory(uri);
    await ch.ready.timeout(const Duration(seconds: 10));
    _ch = ch;
    final ready = Completer<Map<String, dynamic>>();
    _sub = ch.stream.listen(
      (data) {
        if (data is! String) return;
        final e = jsonDecode(data) as Map<String, dynamic>;
        if (!ready.isCompleted) {
          if (e['type'] == 'ready') {
            sessionId = e['sessionId'] as String;
            _setState(ConnState.open);
            ready.complete(e);
            _flushBuffer();
          } else if (e['type'] == 'error') {
            _fatal = true;
            ready.completeError(LiveError(e['code'] as String? ?? 'internal'));
          }
        }
        if (e['type'] == 'error' && e['fatal'] == true) _fatal = true;
        if (e['type'] == 'ended') _fatal = true;
        _events.add(e);
      },
      onDone: () {
        if (!ready.isCompleted) ready.completeError(const LiveError('network'));
        _onDisconnected();
      },
      onError: (_) {},
      cancelOnError: false,
    );
    ch.sink.add(jsonEncode({
      'type': 'start',
      'token': token,
      'protocol': 1,
      'sourceLang': params.sourceLang,
      'targetLang': params.targetLang,
      'saveTranscript': params.saveTranscript,
      if (params.churchSessionId != null) ...{'mode': 'church', 'churchSessionId': params.churchSessionId},
      if (resume && sessionId != null) 'resumeSessionId': sessionId,
      if (resume) 'lastSeq': lastSeq(),
    }));
    return ready.future.timeout(const Duration(seconds: 15), onTimeout: () => throw const LiveError('network'));
  }

  void _onDisconnected() {
    _ch = null;
    if (_closing || _fatal || sessionId == null) {
      _setState(ConnState.closed);
      return;
    }
    unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    _setState(ConnState.reconnecting);
    for (final d in retryDelays) {
      await Future<void>.delayed(d);
      if (_closing) return;
      try {
        await _open(resume: true);
        return;
      } on LiveError catch (e) {
        if (e.code == 'session_not_found' || e.code == 'unauthorized') break;
      } catch (_) {/* sigue intentando */}
    }
    _setState(ConnState.closed);
    _events.add({'type': 'ended', 'reason': 'client_gone', 'transcriptId': null, 'sessionSeconds': -1});
  }

  void sendAudio(Uint8List chunk) {
    if (_state == ConnState.open && _ch != null) {
      // El backend acepta tramas de hasta 64 KB.
      for (var i = 0; i < chunk.length; i += 32000) {
        _ch!.sink.add(chunk.sublist(i, i + 32000 > chunk.length ? chunk.length : i + 32000));
      }
      return;
    }
    if (_state == ConnState.reconnecting || _state == ConnState.connecting) {
      _buffer.add(chunk);
      _bufferedBytes += chunk.length;
      while (_bufferedBytes > maxBufferedBytes && _buffer.isNotEmpty) {
        final old = _buffer.removeAt(0);
        _bufferedBytes -= old.length;
        droppedBytes += old.length;
      }
    }
  }

  void _flushBuffer() {
    final pending = List<Uint8List>.from(_buffer);
    _buffer.clear();
    _bufferedBytes = 0;
    for (final c in pending) {
      sendAudio(c);
    }
  }

  int get bufferedBytes => _bufferedBytes;

  void control(String type) {
    if (_ch != null && _state == ConnState.open) _ch!.sink.add(jsonEncode({'type': type}));
  }

  Future<void> close() async {
    _closing = true;
    await _sub?.cancel();
    await _ch?.sink.close();
    _setState(ConnState.closed);
    await _events.close();
    await _stateCtl.close();
  }
}

class LiveError implements Exception {
  const LiveError(this.code);
  final String code;
  @override
  String toString() => 'LiveError($code)';
}
