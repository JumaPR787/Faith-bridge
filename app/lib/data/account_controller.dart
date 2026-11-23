import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../domain/models.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'purchases_service.dart';

/// Sesión del usuario: autenticación, estado de suscripción y cuota
/// (siempre leídos del servidor).
class AccountController extends ChangeNotifier {
  AccountController({required this.auth, required this.api, required this.purchases}) {
    _sub = auth.userChanges.listen((_) => refresh());
  }

  final AuthGateway auth;
  final ApiClient api;
  final PurchasesService purchases;
  StreamSubscription<String?>? _sub;

  QuotaStatus quota = QuotaStatus.empty;
  bool liveEnabled = true;
  bool churchEnabled = false;
  bool loading = false;
  String? error;
  String? _configuredFor;

  bool get signedIn => auth.userId != null;

  Future<void> refresh() async {
    final uid = auth.userId;
    if (uid == null) {
      quota = QuotaStatus.empty;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      if (_configuredFor != uid) {
        await purchases.configure(uid);
        _configuredFor = uid;
      }
      final me = await api.me();
      quota = QuotaStatus.fromJson(me['quota'] as Map<String, dynamic>);
      final service = me['service'] as Map<String, dynamic>? ?? {};
      liveEnabled = service['liveSessionsEnabled'] as bool? ?? true;
      churchEnabled = service['churchModeEnabled'] as bool? ?? false;
      error = null;
    } on ApiException catch (e) {
      error = e.isNetwork ? 'network' : e.code;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Tras comprar o restaurar: el servidor verifica con la tienda (vía RevenueCat).
  Future<void> syncAfterPurchase() async {
    // La tienda puede tardar unos segundos en notificar; reintento acotado.
    for (var i = 0; i < 4; i++) {
      try {
        quota = await api.syncSubscription();
        notifyListeners();
        if (quota.hasAccess) return;
      } on ApiException {/* reintenta */}
      await Future<void>.delayed(Duration(seconds: 1 + i * 2));
    }
  }

  void updateQuotaRemaining(int remainingSeconds) {
    quota = QuotaStatus(
      plan: quota.plan,
      status: quota.status,
      hasAccess: quota.hasAccess,
      isTrial: quota.isTrial,
      quotaSeconds: quota.quotaSeconds,
      usedSeconds: quota.quotaSeconds - remainingSeconds,
      remainingSeconds: remainingSeconds,
      willRenew: quota.willRenew,
      trialAlreadyUsed: quota.trialAlreadyUsed,
      periodEnd: quota.periodEnd,
      accessUntil: quota.accessUntil,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await purchases.logOut();
    _configuredFor = null;
    await auth.signOut();
    quota = QuotaStatus.empty;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
