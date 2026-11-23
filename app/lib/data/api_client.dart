import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';

class ApiException implements Exception {
  ApiException(this.status, this.code);
  final int status;
  final String code;
  bool get isNetwork => status == 0;
  @override
  String toString() => 'ApiException($status, $code)';
}

/// Cliente HTTP del backend de FaithBridge. Todas las decisiones de cuota y
/// beneficios se toman en el servidor; la app solo muestra el resultado.
class ApiClient {
  ApiClient({required this.baseUrl, required this.token, http.Client? client}) : _http = client ?? http.Client();

  final String baseUrl;
  final Future<String?> Function() token;
  final http.Client _http;

  Future<dynamic> _req(String method, String path, {Object? body}) async {
    final t = await token();
    final headers = <String, String>{
      if (t != null) 'authorization': 'Bearer $t',
      if (body != null) 'content-type': 'application/json',
    };
    final uri = Uri.parse('$baseUrl$path');
    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 60)));
    } catch (_) {
      throw ApiException(0, 'network');
    }
    final decoded = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final code = decoded is Map && decoded['error'] is String ? decoded['error'] as String : 'http_${res.statusCode}';
      throw ApiException(res.statusCode, code);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> me() async => (await _req('GET', '/v1/me')) as Map<String, dynamic>;

  Future<QuotaStatus> syncSubscription() async {
    final j = (await _req('POST', '/v1/subscription/sync')) as Map<String, dynamic>;
    return QuotaStatus.fromJson(j['quota'] as Map<String, dynamic>);
  }

  Future<void> updateSettings({String? uiLocale, int? retentionDays}) =>
      _req('PATCH', '/v1/me/settings', body: {'uiLocale': ?uiLocale, 'transcriptRetentionDays': ?retentionDays});

  Future<List<TranscriptSummary>> transcripts() async {
    final j = (await _req('GET', '/v1/transcripts')) as Map<String, dynamic>;
    return (j['transcripts'] as List).map((e) => TranscriptSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TranscriptDetail> transcript(String id) async {
    final j = (await _req('GET', '/v1/transcripts/$id')) as Map<String, dynamic>;
    return TranscriptDetail(
      summary: TranscriptSummary.fromJson({...j, 'segmentCount': (j['segments'] as List).length}),
      segments: (j['segments'] as List).map((e) => SavedSegment.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> deleteTranscript(String id) => _req('DELETE', '/v1/transcripts/$id');

  Map<String, Object?> _tBody(Lang source, Lang target, {String? text, String? transcriptId, bool? confirm}) => {
        'source': source.code,
        'target': target.code,
        'text': ?text,
        'transcriptId': ?transcriptId,
        'confirm': ?confirm,
      };

  Future<TextEstimate> estimate(Lang source, Lang target, {String? text, String? transcriptId}) async =>
      TextEstimate.fromJson((await _req('POST', '/v1/translate/estimate', body: _tBody(source, target, text: text, transcriptId: transcriptId))) as Map<String, dynamic>);

  Future<Map<String, dynamic>> translate(Lang source, Lang target, {String? text, String? transcriptId}) async =>
      (await _req('POST', '/v1/translate', body: _tBody(source, target, text: text, transcriptId: transcriptId, confirm: true))) as Map<String, dynamic>;

  Future<Map<String, dynamic>> glossary(Lang source, Lang target) async =>
      (await _req('GET', '/v1/glossary?source=${source.code}&target=${target.code}')) as Map<String, dynamic>;

  Future<void> addTerm(Lang source, Lang target, String s, String t) =>
      _req('POST', '/v1/glossary', body: {'source': source.code, 'target': target.code, 'sourceTerm': s, 'targetTerm': t});

  Future<void> deleteTerm(String id) => _req('DELETE', '/v1/glossary/$id');

  Future<Map<String, dynamic>> deleteAccount() async => (await _req('DELETE', '/v1/account')) as Map<String, dynamic>;
}

/// Modo iglesia (fase 2).
extension ChurchApi on ApiClient {
  Future<Map<String, dynamic>> orgs() async => (await _req('GET', '/v1/orgs')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> org(String id) async => (await _req('GET', '/v1/orgs/$id')) as Map<String, dynamic>;
  Future<String> createOrg(String name) async =>
      ((await _req('POST', '/v1/orgs', body: {'name': name, 'attestAudioAuthorization': true})) as Map<String, dynamic>)['id'] as String;
  Future<void> addMember(String orgId, String email, String role) => _req('POST', '/v1/orgs/$orgId/members', body: {'email': email, 'role': role});
  Future<void> removeMember(String orgId, String userId) => _req('DELETE', '/v1/orgs/$orgId/members/$userId');
  Future<Map<String, dynamic>> createChurchSession(String orgId, {required Lang source, Lang? target, required int maxListeners, required bool save}) async =>
      (await _req('POST', '/v1/orgs/$orgId/sessions', body: {
        'sourceLang': source.code,
        'targetLang': target?.code,
        'maxListeners': maxListeners,
        'saveTranscript': save,
        'attestAudioAuthorization': true,
      })) as Map<String, dynamic>;
  Future<void> endChurchSession(String orgId, String sessionId) => _req('POST', '/v1/orgs/$orgId/sessions/$sessionId/end');

  /// Unirse como asistente (no requiere cuenta).
  Future<Map<String, dynamic>> joinChurch(String code) async => (await _req('POST', '/v1/church/join', body: {'code': code})) as Map<String, dynamic>;
}
