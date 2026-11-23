/// Estado de los subtítulos de una sesión, independiente de la interfaz.
///
/// Reglas:
///  - Los segmentos confirmados se indexan por `seq` (id asignado por el servidor).
///  - Un segmento repetido (p. ej. reenviado tras reconexión) no se duplica.
///  - Una traducción que llega tarde o desordenada se coloca en su `seq`.
///  - El texto provisional (interim) solo se muestra para el seq siguiente al
///    último confirmado; un interim antiguo o retrasado se descarta.
class LiveSegment {
  LiveSegment({required this.seq, required this.startMs, required this.endMs, required this.text, this.unclearCount = 0});

  final int seq;
  final int startMs;
  final int endMs;
  final String text;
  final int unclearCount;
  String? translation;
  TranslationState translationState = TranslationState.pending;
}

enum TranslationState { pending, ok, failed, none }

class TranscriptStore {
  TranscriptStore({required this.translationEnabled});

  final bool translationEnabled;
  final Map<int, LiveSegment> _segments = {};
  final Map<int, ({String status, String? text})> _earlyTranslations = {};
  String? _interimText;
  int? _interimSeq;

  /// Último seq confirmado (-1 si ninguno). Se usa para reanudar.
  int get lastSeq => _segments.isEmpty ? -1 : _segments.keys.reduce((a, b) => a > b ? a : b);

  List<LiveSegment> get segments {
    final list = _segments.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));
    return list;
  }

  String? get interim => (_interimSeq != null && _interimSeq! > lastSeq) ? _interimText : null;

  /// Aplica un evento del servidor. Devuelve true si cambió algo visible.
  bool apply(Map<String, dynamic> e) {
    switch (e['type']) {
      case 'interim':
        final seq = (e['seq'] as num).toInt();
        if (seq <= lastSeq) return false; // retrasado: ya confirmado
        _interimSeq = seq;
        _interimText = e['text'] as String;
        return true;
      case 'segment':
        final seq = (e['seq'] as num).toInt();
        if (_segments.containsKey(seq)) return false; // duplicado
        final s = LiveSegment(
          seq: seq,
          startMs: (e['startMs'] as num).toInt(),
          endMs: (e['endMs'] as num).toInt(),
          text: e['text'] as String,
          unclearCount: (e['unclearCount'] as num?)?.toInt() ?? 0,
        );
        if (!translationEnabled) s.translationState = TranslationState.none;
        final early = _earlyTranslations.remove(seq);
        if (early != null) _setTranslation(s, early.status, early.text);
        _segments[seq] = s;
        if (_interimSeq != null && _interimSeq! <= seq) {
          _interimSeq = null;
          _interimText = null;
        }
        return true;
      case 'translation':
        final seq = (e['seq'] as num).toInt();
        final status = e['status'] as String;
        final text = e['text'] as String?;
        final s = _segments[seq];
        if (s == null) {
          _earlyTranslations[seq] = (status: status, text: text);
          return false;
        }
        if (s.translationState == TranslationState.ok) return false; // ya aplicada
        _setTranslation(s, status, text);
        return true;
      default:
        return false;
    }
  }

  void _setTranslation(LiveSegment s, String status, String? text) {
    if (status == 'ok' && text != null) {
      s.translation = text;
      s.translationState = TranslationState.ok;
    } else {
      s.translationState = TranslationState.failed;
    }
  }

  /// Texto plano para copiar/compartir al terminar.
  String toPlainText({required bool includeOriginal, required bool includeTranslation}) {
    final b = StringBuffer();
    for (final s in segments) {
      if (includeOriginal) b.writeln(s.text);
      if (includeTranslation && s.translation != null) b.writeln(s.translation);
      b.writeln();
    }
    return b.toString().trim();
  }

  void clear() {
    _segments.clear();
    _earlyTranslations.clear();
    _interimSeq = null;
    _interimText = null;
  }
}
