import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:faithbridge/data/account_controller.dart';
import 'package:faithbridge/data/api_client.dart';
import 'package:faithbridge/data/auth_service.dart';
import 'package:faithbridge/data/purchases_service.dart';
import 'package:faithbridge/domain/models.dart';
import 'package:faithbridge/features/plans/plans_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _Auth implements AuthGateway {
  @override
  String? get userId => 'u1';
  @override
  Stream<String?> get userChanges => const Stream.empty();
  @override
  Future<String?> accessToken() async => 't';
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<void> verifyCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

PlanOffer offer(String id, String price, {bool trial = false}) => PlanOffer(
      package: Package('\$rc_monthly', PackageType.monthly, StoreProduct(id, '', '', 0, price, 'USD'), const PresentedOfferingContext('o', null, null)),
      priceString: price,
      trialEligible: trial,
      productId: id,
    );

/// Compras SIMULADAS para la prueba (no toca la tienda).
class FakePurchases extends PurchasesService {
  FakePurchases({this.active = const []});
  final List<String> active;
  PlanOffer? bought;
  String? replacing;
  @override
  Future<PlanOffer?> personalOffer() async => offer('fb_personal_monthly:monthly', r'$5.99', trial: true);
  @override
  Future<PlanOffer?> churchOffer() async => offer('fb_church_monthly:monthly', r'$29.99');
  @override
  Future<List<String>> activeProductIds() async => active;
  @override
  Future<PurchaseOutcome> buy(PlanOffer offer, {String? replacingProductId}) async {
    bought = offer;
    replacing = replacingProductId;
    return PurchaseOutcome.cancelled;
  }
}

QuotaStatus quota(String plan) => QuotaStatus(
      plan: plan,
      status: plan == 'none' ? 'none' : 'active',
      hasAccess: plan != 'none',
      isTrial: false,
      quotaSeconds: 18000,
      usedSeconds: 0,
      remainingSeconds: 18000,
      willRenew: true,
      trialAlreadyUsed: false,
    );

Future<FakePurchases> pump(WidgetTester t, {required String plan, required bool churchEnabled, List<String> active = const []}) async {
  final p = FakePurchases(active: active);
  final auth = _Auth();
  final account = AccountController(auth: auth, api: ApiClient(baseUrl: 'http://x', token: auth.accessToken), purchases: p)
    ..quota = quota(plan)
    ..churchEnabled = churchEnabled;
  await t.pumpWidget(ChangeNotifierProvider.value(
    value: account,
    child: const MaterialApp(
      locale: Locale('es'),
      supportedLocales: [Locale('es'), Locale('en')],
      localizationsDelegates: [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: PlansScreen(),
    ),
  ));
  await t.pumpAndSettle();
  return p;
}

void main() {
  testWidgets('sin modo iglesia habilitado no se ofrece el plan Iglesia', (t) async {
    await pump(t, plan: 'none', churchEnabled: false);
    expect(find.text('Plan Personal'), findsOneWidget);
    expect(find.text('Plan Iglesia'), findsNothing);
    expect(find.textContaining(r'$5.99'), findsOneWidget);
    expect(find.text('Comenzar prueba'), findsOneWidget);
  });

  testWidgets('con modo iglesia: muestra ambos planes con el precio de la tienda', (t) async {
    final p = await pump(t, plan: 'none', churchEnabled: true);
    expect(find.text('Plan Iglesia'), findsOneWidget);
    expect(find.textContaining(r'$29.99'), findsOneWidget);
    expect(find.textContaining('600 minutos'), findsOneWidget);
    // Sin plan: suscribirse al plan Iglesia no reemplaza nada.
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Suscribirme'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Suscribirme'));
    await t.pumpAndSettle();
    expect(p.bought!.productId, 'fb_church_monthly:monthly');
    expect(p.replacing, isNull);
  });

  testWidgets('con plan Personal: «Cambiar al plan Iglesia» reemplaza la suscripción Personal', (t) async {
    final p = await pump(t, plan: 'personal', churchEnabled: true, active: ['fb_personal_monthly:monthly']);
    expect(find.text('Plan actual'), findsOneWidget);
    expect(find.text('Comenzar prueba'), findsNothing);
    expect(find.textContaining('prorrateo'), findsOneWidget);
    await t.ensureVisible(find.text('Cambiar al plan Iglesia'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cambiar al plan Iglesia'));
    await t.pumpAndSettle();
    expect(p.bought!.productId, 'fb_church_monthly:monthly');
    expect(p.replacing, 'fb_personal_monthly:monthly');
  });

  testWidgets('con plan Iglesia: es el plan actual e incluye el uso personal', (t) async {
    await pump(t, plan: 'church', churchEnabled: true);
    expect(find.text('Plan actual'), findsOneWidget);
    expect(find.text('Tu plan Iglesia ya incluye el uso personal.'), findsOneWidget);
    expect(find.text('Suscribirme'), findsNothing);
    expect(find.text('Cambiar al plan Iglesia'), findsNothing);
  });
}
