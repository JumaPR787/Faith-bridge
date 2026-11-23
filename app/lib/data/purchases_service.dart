import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/config.dart';

/// Lo que la pantalla de planes necesita saber de la tienda.
class PlanOffer {
  PlanOffer({required this.package, required this.priceString, required this.trialEligible, required this.productId});
  final Package package;
  final String priceString; // precio LOCALIZADO que devuelve la tienda
  final bool trialEligible;
  final String productId;
}

enum PurchaseOutcome { success, cancelled, pending, failed }

/// Compras dentro de la app con las tiendas oficiales (StoreKit / Google Play
/// Billing) a través de RevenueCat. La app nunca pide tarjetas ni valida
/// pagos: después de comprar o restaurar, el backend consulta el estado.
class PurchasesService {
  bool _configured = false;

  bool get available => _apiKey.isNotEmpty;

  String get _apiKey => Platform.isIOS ? AppConfig.revenueCatAppleKey : AppConfig.revenueCatGoogleKey;

  /// El appUserID es el id de usuario de Supabase: así el beneficio se
  /// sincroniza entre dispositivos de la misma cuenta.
  Future<void> configure(String appUserId) async {
    if (!available) return;
    if (!_configured) {
      await Purchases.configure(PurchasesConfiguration(_apiKey)..appUserID = appUserId);
      _configured = true;
    } else {
      await Purchases.logIn(appUserId);
    }
  }

  Future<void> logOut() async {
    if (_configured) {
      try {
        await Purchases.logOut();
      } catch (_) {/* usuario anónimo: nada que cerrar */}
    }
  }

  Future<PlanOffer?> personalOffer() async {
    if (!_configured) return null;
    final offerings = await Purchases.getOfferings();
    final offering = offerings.all[AppConfig.revenueCatOffering] ?? offerings.current;
    final pkg = offering?.monthly ?? offering?.availablePackages.firstOrNull;
    if (pkg == null) return null;
    final product = pkg.storeProduct;
    var eligible = false;
    if (Platform.isIOS) {
      // iOS: la elegibilidad de la prueba la determina StoreKit.
      final m = await Purchases.checkTrialOrIntroductoryPriceEligibility([product.identifier]);
      eligible = m[product.identifier]?.status == IntroEligibilityStatus.introEligibilityStatusEligible && product.introductoryPrice != null;
    } else {
      // Android: Google Play solo devuelve la fase gratuita si el usuario es elegible.
      eligible = product.defaultOption?.freePhase != null;
    }
    return PlanOffer(package: pkg, priceString: product.priceString, trialEligible: eligible, productId: product.identifier);
  }

  Future<PurchaseOutcome> buy(PlanOffer offer) async {
    try {
      await Purchases.purchase(PurchaseParams.package(offer.package));
      return PurchaseOutcome.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return PurchaseOutcome.cancelled;
      if (code == PurchasesErrorCode.paymentPendingError) return PurchaseOutcome.pending;
      return PurchaseOutcome.failed;
    }
  }

  /// Devuelve true si la tienda informó alguna suscripción activa.
  Future<bool> restore() async {
    if (!_configured) return false;
    final info = await Purchases.restorePurchases();
    return info.activeSubscriptions.isNotEmpty;
  }

  Future<String?> managementUrl() async {
    if (_configured) {
      final info = await Purchases.getCustomerInfo();
      if (info.managementURL != null) return info.managementURL;
    }
    return Platform.isIOS ? 'https://apps.apple.com/account/subscriptions' : 'https://play.google.com/store/account/subscriptions';
  }
}
