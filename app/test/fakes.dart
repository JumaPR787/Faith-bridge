import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:faithbridge/data/audio_capture.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeSink extends DelegatingStreamSink<dynamic> implements WebSocketSink {
  FakeSink(super.sink);
  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) => super.close();
}

/// Canal WebSocket simulado: lo que envía la app queda en [sent]; el "servidor"
/// de la prueba responde con [push] o corta la conexión con [drop].
class FakeChannel extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  FakeChannel(this.server) {
    _fromClient.stream.listen((m) {
      sent.add(m);
      server.onClientMessage(this, m);
    });
  }

  final FakeServer server;
  final _toClient = StreamController<dynamic>();
  final _fromClient = StreamController<dynamic>();
  late final FakeSink _sink = FakeSink(_fromClient.sink);
  final List<dynamic> sent = [];

  List<Map<String, dynamic>> get sentJson => sent.whereType<String>().map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  int get sentAudioBytes => sent.whereType<Uint8List>().fold(0, (n, b) => n + b.length);

  void push(Map<String, dynamic> e) => _toClient.add(jsonEncode(e));
  Future<void> drop() => _toClient.close();

  @override
  Stream<dynamic> get stream => _toClient.stream;
  @override
  WebSocketSink get sink => _sink;
  @override
  Future<void> get ready => Future.value();
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
}

class FakeServer {
  final List<FakeChannel> channels = [];
  bool autoReady = true;
  String? failWith;
  int remainingSeconds = 18000;

  FakeChannel connect(Uri _) {
    final c = FakeChannel(this);
    channels.add(c);
    return c;
  }

  FakeChannel get last => channels.last;

  void onClientMessage(FakeChannel c, dynamic m) {
    if (m is! String) return;
    final j = jsonDecode(m) as Map<String, dynamic>;
    if (j['type'] == 'start') {
      if (failWith != null) {
        c.push({'type': 'error', 'code': failWith, 'fatal': true});
        return;
      }
      if (autoReady) {
        c.push({
          'type': 'ready',
          'sessionId': '00000000-0000-0000-0000-000000000001',
          'resumed': j.containsKey('resumeSessionId'),
          'quota': {'quotaSeconds': 18000, 'usedSeconds': 0, 'remainingSeconds': remainingSeconds, 'periodEnd': null, 'isTrial': false},
          'maxSessionSeconds': 10800,
          'translation': j['targetLang'] != null,
          'simulated': true,
        });
      }
    } else if (j['type'] == 'stop') {
      c.push({'type': 'ended', 'reason': 'user_stopped', 'transcriptId': null, 'sessionSeconds': 3});
    }
  }
}

class FakeAudio implements AudioSource {
  bool permission = true;
  final _ctl = StreamController<Uint8List>.broadcast();
  final _int = StreamController<void>.broadcast();
  bool started = false;
  bool paused = false;

  void emit(int bytes) => _ctl.add(Uint8List(bytes));
  void interrupt() => _int.add(null);

  @override
  Stream<void> get interruptions => _int.stream;
  @override
  Future<bool> ensurePermission() async => permission;
  @override
  Future<Stream<Uint8List>> start() async {
    started = true;
    return _ctl.stream;
  }

  @override
  Future<void> pause() async => paused = true;
  @override
  Future<void> resume() async => paused = false;
  @override
  Future<void> stop() async => started = false;
}
