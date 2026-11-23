import 'dart:typed_data';

import 'package:faithbridge/data/live_connection.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  LiveConnection make(FakeServer server, {int lastSeq = -1}) => LiveConnection(
        uri: Uri.parse('ws://test/v1/live'),
        tokenProvider: () async => 'token-123456789',
        params: LiveStartParams(sourceLang: 'en', targetLang: 'es', saveTranscript: false),
        lastSeq: () => lastSeq,
        channelFactory: server.connect,
        retryDelays: const [Duration(milliseconds: 10), Duration(milliseconds: 10)],
        maxBufferedBytes: 1000,
      );

  test('envía el token en el primer mensaje (no en la URL) y recibe ready', () async {
    final server = FakeServer();
    final c = make(server);
    final ready = await c.connect();
    expect(ready['type'], 'ready');
    final start = server.last.sentJson.first;
    expect(start['type'], 'start');
    expect(start['token'], 'token-123456789');
    expect(c.state, ConnState.open);
  });

  test('error fatal del servidor se propaga como LiveError', () async {
    final server = FakeServer()..failWith = 'no_entitlement';
    final c = make(server);
    expect(c.connect(), throwsA(isA<LiveError>().having((e) => e.code, 'code', 'no_entitlement')));
  });

  test('tras un corte reanuda la misma sesión con lastSeq y no acumula audio sin límite', () async {
    final server = FakeServer();
    final c = make(server, lastSeq: 7);
    await c.connect();
    server.autoReady = false; // el servidor tarda en aceptar la reanudación
    await server.last.drop();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.state, ConnState.reconnecting);
    // Mientras tanto llegan 5 KB de audio: solo se guardan 1000 bytes.
    for (var i = 0; i < 5; i++) {
      c.sendAudio(Uint8List(1000));
    }
    expect(c.bufferedBytes, 1000);
    expect(c.droppedBytes, 4000);
    final resumeMsg = server.last.sentJson.first;
    expect(resumeMsg['resumeSessionId'], '00000000-0000-0000-0000-000000000001');
    expect(resumeMsg['lastSeq'], 7);
    server.last.push({'type': 'ready', 'sessionId': '00000000-0000-0000-0000-000000000001', 'resumed': true, 'quota': {'remainingSeconds': 1}});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.state, ConnState.open);
    expect(server.last.sentAudioBytes, 1000); // se vació el búfer acotado
  });

  test('si no logra reconectar, emite fin de sesión', () async {
    final server = FakeServer();
    final c = make(server);
    await c.connect();
    final events = <Map<String, dynamic>>[];
    c.events.listen(events.add);
    server.failWith = 'session_not_found';
    await server.last.drop();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(c.state, ConnState.closed);
    expect(events.last['type'], 'ended');
  });
}
