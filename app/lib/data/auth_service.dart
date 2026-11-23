import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstracción de autenticación (permite sustituirla en pruebas).
abstract class AuthGateway {
  String? get userId;
  Stream<String?> get userChanges;
  Future<String?> accessToken();
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();
}

/// Inicio de sesión sin contraseña con código de un solo uso por correo
/// (Supabase Auth). No requiere configurar inicio con Apple/Google.
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);
  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get userChanges => _client.auth.onAuthStateChange.map((s) => s.session?.user.id);

  @override
  Future<String?> accessToken() async {
    var session = _client.auth.currentSession;
    if (session == null) return null;
    final exp = session.expiresAt;
    if (exp != null && DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now().add(const Duration(minutes: 2)))) {
      session = (await _client.auth.refreshSession()).session;
    }
    return session?.accessToken;
  }

  @override
  Future<void> sendCode(String email) => _client.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<void> verifyCode(String email, String code) async {
    await _client.auth.verifyOTP(email: email, token: code, type: OtpType.email);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
