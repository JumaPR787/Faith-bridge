import 'package:faithbridge/data/live_connection.dart';
import 'package:faithbridge/domain/transcript_store.dart';
import 'package:faithbridge/features/church/join_screen.dart';
import 'package:faithbridge/features/church/listener_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('código para unirse', () {
    test('acepta minúsculas, espacios, guiones y el prefijo del QR', () {
      expect(normalizeJoinCode('abcd2345'), 'ABCD-2345');
      expect(normalizeJoinCode(' ab cd-23 45 '), 'ABCD-2345');
      expect(normalizeJoinCode('FAITHBRIDGE:ABCD-2345'), 'ABCD-2345');
    });
    test('rechaza caracteres ambiguos y longitudes incorrectas', () {
      expect(normalizeJoinCode('ABCD-0O1I'), isNull); // 0, O, 1, I no se usan
      expect(normalizeJoinCode('ABC'), isNull);
      expect(normalizeJoinCode('https://example.com'), isNull);
    });
  });

  test('el organizador envía mode=church y el id de la sesión', () async {
    final server = FakeServer();
    final c = LiveConnection(
      uri: Uri.parse('ws://x/v1/live'),
      tokenProvider: () async => 'token-123456789',
      params: LiveStartParams(sourceLang: 'en', targetLang: 'es', saveTranscript: false, churchSessionId: 'cs-1'),
      lastSeq: () => -1,
      channelFactory: server.connect,
    );
    await c.connect();
    final start = server.last.sentJson.first;
    expect(start['mode'], 'church');
    expect(start['churchSessionId'], 'cs-1');
  });

  test('asistente: espera, recibe texto, interrupción y fin; nunca envía audio', () async {
    final server = FakeServer();
    final c = ListenerController(token: 'listener-token-123', translation: true, channelFactory: server.connect, keepScreenOn: false);
    await c.start();
    final ch = server.last;
    await Future<void>.delayed(Duration.zero);
    expect(ch.sentJson.single, {'type': 'listen', 'token': 'listener-token-123', 'lastSeq': -1});

    ch.push({'type': 'joined', 'churchSessionId': 'cs', 'orgName': 'Iglesia', 'sourceLang': 'en', 'targetLang': 'es', 'broadcasting': false});
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, ListenerPhase.waiting);

    ch.push({'type': 'segment', 'seq': 0, 'startMs': 0, 'endMs': 900, 'text': 'Good morning.', 'unclearCount': 0});
    ch.push({'type': 'translation', 'seq': 0, 'status': 'ok', 'text': 'Buenos días.'});
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, ListenerPhase.live);
    expect(c.store.segments.single.translation, 'Buenos días.');
    expect(c.store.segments.single.translationState, TranslationState.ok);

    ch.push({'type': 'broadcast_interrupted'});
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, ListenerPhase.interrupted);

    ch.push({'type': 'ended', 'reason': 'user_stopped', 'transcriptId': null, 'sessionSeconds': 60});
    await Future<void>.delayed(Duration.zero);
    expect(c.phase, ListenerPhase.ended);
    expect(ch.sentAudioBytes, 0);
    c.dispose();
  });
}
