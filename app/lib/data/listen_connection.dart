import 'dart:async';
import 'dart:convert';

import 'live_connection.dart' show ChannelFactory, ConnState;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Conexión de SOLO LECTURA de un asistente del modo iglesia.
/// No usa el micrófono ni envía audio. Reconecta con espera creciente y pide
/// solo los segmentos posteriores al último recibido.
class ListenConnection {
  ListenConnection({
    required this.uri,
    required this.token,
    required this.lastSeq,
    ChannelFactory? channelFactory,
    this.retryDelays = const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8), Duration(seconds: 15), Duration(seconds: 30)],
  }) : _factory = channelFactory ?? ((u) => WebSocketChannel.connect(u));

  final Uri uri;
  final String token;
  final int Function() lastSeq;
  final List<Duration> retryDelays;
  final ChannelFactory _factory;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _states = StreamController<ConnState>.broadcast();
  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _sub;
  bool _closing = false;
  bool _final = false;
  ConnState state = ConnState.idle;

  Stream<Map<String, dynamic>> get events => _events.stream;
  Stream<ConnState> get states => _states.stream;

  void _set(ConnState s) {
    state = s;
    if (!_states.isClosed) _states.add(s);
  }

  Future<void> connect() async {
    _set(ConnState.connecting);
    await _open();
  }

  Future<void> _open() async {
    final ch = _factory(uri);
    await ch.ready.timeout(const Duration(seconds: 10));
    _ch = ch;
    _sub = ch.stream.listen(
      (data) {
        if (data is! String) return;
        final e = jsonDecode(data) as Map<String, dynamic>;
        if (e['type'] == 'joined') _set(ConnState.open);
        if (e['type'] == 'ended' || (e['type'] == 'error' && e['fatal'] == true)) _final = true;
        if (!_events.isClosed) _events.add(e);
      },
      onDone: _onDone,
      onError: (_) {},
    );
    ch.sink.add(jsonEncode({'type': 'listen', 'token': token, 'lastSeq': lastSeq()}));
  }

  void _onDone() {
    _ch = null;
    if (_closing || _final) {
      _set(ConnState.closed);
      return;
    }
    unawaited(_reconnect());
  }

  Future<void> _reconnect() async {
    _set(ConnState.reconnecting);
    for (final d in retryDelays) {
      await Future<void>.delayed(d);
      if (_closing) return;
      try {
        await _open();
        return;
      } catch (_) {/* reintenta */}
    }
    _set(ConnState.closed);
    if (!_events.isClosed) _events.add({'type': 'error', 'code': 'network', 'fatal': true});
  }

  Future<void> close() async {
    _closing = true;
    await _sub?.cancel();
    await _ch?.sink.close();
    _set(ConnState.closed);
    await _events.close();
    await _states.close();
  }
}
