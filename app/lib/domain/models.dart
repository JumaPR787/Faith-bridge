enum Lang {
  en,
  es;

  String get code => name;
  Lang get other => this == Lang.en ? Lang.es : Lang.en;
  static Lang parse(String s) => s == 'es' ? Lang.es : Lang.en;
}

/// Qué se muestra en pantalla durante la sesión.
enum DisplayMode { original, translation, both }

class QuotaStatus {
  QuotaStatus({
    required this.plan,
    required this.status,
    required this.hasAccess,
    required this.isTrial,
    required this.quotaSeconds,
    required this.usedSeconds,
    required this.remainingSeconds,
    required this.willRenew,
    required this.trialAlreadyUsed,
    this.periodEnd,
    this.accessUntil,
  });

  final String plan;
  final String status;
  final bool hasAccess;
  final bool isTrial;
  final int quotaSeconds;
  final int usedSeconds;
  final int remainingSeconds;
  final bool willRenew;
  final bool trialAlreadyUsed;
  final DateTime? periodEnd;
  final DateTime? accessUntil;

  static final empty = QuotaStatus(
    plan: 'none',
    status: 'none',
    hasAccess: false,
    isTrial: false,
    quotaSeconds: 0,
    usedSeconds: 0,
    remainingSeconds: 0,
    willRenew: false,
    trialAlreadyUsed: false,
  );

  factory QuotaStatus.fromJson(Map<String, dynamic> j) => QuotaStatus(
        plan: j['plan'] as String? ?? 'none',
        status: j['status'] as String? ?? 'none',
        hasAccess: j['hasAccess'] as bool? ?? false,
        isTrial: j['isTrial'] as bool? ?? false,
        quotaSeconds: (j['quotaSeconds'] as num?)?.toInt() ?? 0,
        usedSeconds: (j['usedSeconds'] as num?)?.toInt() ?? 0,
        remainingSeconds: (j['remainingSeconds'] as num?)?.toInt() ?? 0,
        willRenew: j['willRenew'] as bool? ?? false,
        trialAlreadyUsed: j['trialAlreadyUsed'] as bool? ?? false,
        periodEnd: _date(j['periodEnd']),
        accessUntil: _date(j['accessUntil']),
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

class TranscriptSummary {
  TranscriptSummary({required this.id, required this.title, required this.sourceLang, this.targetLang, required this.createdAt, required this.segmentCount});
  final String id;
  final String title;
  final Lang sourceLang;
  final Lang? targetLang;
  final DateTime createdAt;
  final int segmentCount;

  factory TranscriptSummary.fromJson(Map<String, dynamic> j) => TranscriptSummary(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        sourceLang: Lang.parse(j['sourceLang'] as String),
        targetLang: j['targetLang'] == null ? null : Lang.parse(j['targetLang'] as String),
        createdAt: _date(j['createdAt']) ?? DateTime.now(),
        segmentCount: (j['segmentCount'] as num?)?.toInt() ?? 0,
      );
}

class SavedSegment {
  SavedSegment({required this.seq, required this.startMs, required this.sourceText, this.translatedText, required this.translationStatus});
  final int seq;
  final int startMs;
  final String sourceText;
  final String? translatedText;
  final String translationStatus;

  factory SavedSegment.fromJson(Map<String, dynamic> j) => SavedSegment(
        seq: (j['seq'] as num).toInt(),
        startMs: (j['startMs'] as num).toInt(),
        sourceText: j['sourceText'] as String,
        translatedText: j['translatedText'] as String?,
        translationStatus: j['translationStatus'] as String? ?? 'none',
      );
}

class TranscriptDetail {
  TranscriptDetail({required this.summary, required this.segments});
  final TranscriptSummary summary;
  final List<SavedSegment> segments;
}

class TextEstimate {
  TextEstimate({required this.chars, required this.costSeconds, required this.remainingSeconds, required this.allowed, this.reason});
  final int chars;
  final int costSeconds;
  final int remainingSeconds;
  final bool allowed;
  final String? reason;

  factory TextEstimate.fromJson(Map<String, dynamic> j) => TextEstimate(
        chars: (j['chars'] as num).toInt(),
        costSeconds: (j['costSeconds'] as num).toInt(),
        remainingSeconds: (j['remainingSeconds'] as num).toInt(),
        allowed: j['allowed'] as bool,
        reason: j['reason'] as String?,
      );
}

String formatMinutes(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m min' : '$m min ${s.toString().padLeft(2, '0')} s';
}

String formatClock(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
