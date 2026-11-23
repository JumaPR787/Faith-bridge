import 'package:faithbridge/domain/transcript_store.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> seg(int seq, String text) => {'type': 'segment', 'seq': seq, 'startMs': seq * 1000, 'endMs': seq * 1000 + 900, 'text': text, 'unclearCount': 0};
Map<String, dynamic> tr(int seq, String? text, [String status = 'ok']) => {'type': 'translation', 'seq': seq, 'status': status, 'text': text};

void main() {
  test('ordena por seq aunque lleguen desordenados y no duplica', () {
    final s = TranscriptStore(translationEnabled: true);
    s.apply(seg(1, 'B'));
    s.apply(seg(0, 'A'));
    expect(s.apply(seg(1, 'B')), isFalse);
    expect(s.segments.map((x) => x.text), ['A', 'B']);
    expect(s.lastSeq, 1);
  });

  test('traducciones retrasadas o adelantadas se colocan en su segmento', () {
    final s = TranscriptStore(translationEnabled: true);
    s.apply(tr(0, 'Hola')); // llega antes que el segmento
    s.apply(seg(0, 'Hello'));
    s.apply(seg(1, 'World'));
    s.apply(tr(1, null, 'failed'));
    expect(s.segments[0].translation, 'Hola');
    expect(s.segments[0].translationState, TranslationState.ok);
    expect(s.segments[1].translationState, TranslationState.failed);
    expect(s.apply(tr(0, 'Otra')), isFalse); // no se sobrescribe
    expect(s.segments[0].translation, 'Hola');
  });

  test('el texto provisional desaparece al confirmarse y se ignora si llega tarde', () {
    final s = TranscriptStore(translationEnabled: false);
    s.apply({'type': 'interim', 'seq': 0, 'text': 'good mor'});
    expect(s.interim, 'good mor');
    s.apply(seg(0, 'Good morning.'));
    expect(s.interim, isNull);
    expect(s.apply({'type': 'interim', 'seq': 0, 'text': 'good mor'}), isFalse);
    expect(s.interim, isNull);
    expect(s.segments.first.translationState, TranslationState.none);
  });

  test('texto plano para copiar', () {
    final s = TranscriptStore(translationEnabled: true)
      ..apply(seg(0, 'Hello'))
      ..apply(tr(0, 'Hola'));
    expect(s.toPlainText(includeOriginal: true, includeTranslation: true), 'Hello\nHola');
  });
}
