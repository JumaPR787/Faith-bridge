import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:faithbridge/data/account_controller.dart';
import 'package:faithbridge/data/api_client.dart';
import 'package:faithbridge/data/auth_service.dart';
import 'package:faithbridge/data/live_connection.dart';
import 'package:faithbridge/data/purchases_service.dart';
import 'package:faithbridge/data/settings_controller.dart';
import 'package:faithbridge/domain/models.dart';
import 'package:faithbridge/features/live/live_controller.dart';
import 'package:faithbridge/features/live/live_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class FakeAuth implements AuthGateway {
  @override
  String? get userId => 'u1';
  @override
  Stream<String?> get userChanges => const Stream.empty();
  @override
  Future<String?> accessToken() async => 'token-123456789';
  @override
  Future<void> sendCode(String email) async {}
  @override
  Future<void> verifyCode(String email, String code) async {}
  @override
  Future<void> signOut() async {}
}

Widget appEs(Widget home) => MaterialApp(
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: home,
    );

void main() {
  testWidgets('recorrido en vivo: iniciar → subtítulos → traducción → pausa → finalizar', (tester) async {
    SharedPreferences.setMockInitialValues({'uiLocale': 'es', 'keepScreenOn': false});
    final settings = await SettingsController.load();
    final auth = FakeAuth();
    final account = AccountController(auth: auth, api: ApiClient(baseUrl: 'http://x', token: auth.accessToken), purchases: PurchasesService());
    final server = FakeServer();
    final audio = FakeAudio();
    final controller = LiveController(
      audio: audio,
      connectionFactory: (p, lastSeq) => LiveConnection(uri: Uri.parse('ws://x/v1/live'), tokenProvider: auth.accessToken, params: p, lastSeq: lastSeq, channelFactory: server.connect),
      source: Lang.en,
      target: Lang.es,
      save: false,
      keepScreenOn: false,
    );

    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: settings), ChangeNotifierProvider.value(value: account)],
      child: appEs(LiveScreen(source: Lang.en, display: DisplayMode.both, save: false, controller: controller)),
    ));

    // El micrófono NO se activa hasta tocar «Iniciar».
    expect(audio.started, isFalse);
    expect(find.text('Micrófono activo'), findsNothing);
    await tester.runAsync(() async {
      await tester.tap(find.text('Iniciar'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(audio.started, isTrue);
    expect(find.text('Micrófono activo'), findsOneWidget);
    expect(find.text('DATOS SIMULADOS (desarrollo)'), findsOneWidget);

    // El audio capturado se envía al servidor.
    await tester.runAsync(() async {
      audio.emit(3200);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    expect(server.last.sentAudioBytes, 3200);

    // Servidor: provisional, confirmado y traducción.
    await tester.runAsync(() async {
      server.last.push({'type': 'interim', 'seq': 0, 'text': 'Good mor'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Good mor'), findsOneWidget);
    await tester.runAsync(() async {
      server.last.push({'type': 'segment', 'seq': 0, 'startMs': 0, 'endMs': 900, 'text': 'Good morning church.', 'unclearCount': 0});
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Good mor'), findsNothing);
    expect(find.text('Good morning church.'), findsOneWidget);
    expect(find.text('Traduciendo…'), findsOneWidget);
    await tester.runAsync(() async {
      server.last.push({'type': 'translation', 'seq': 0, 'status': 'ok', 'text': 'Buenos días, iglesia.'});
      server.last.push({'type': 'segment', 'seq': 1, 'startMs': 900, 'endMs': 1800, 'text': 'Let us pray.', 'unclearCount': 0});
      server.last.push({'type': 'translation', 'seq': 1, 'status': 'failed', 'text': null});
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Buenos días, iglesia.'), findsOneWidget);
    expect(find.text('[traducción no disponible]'), findsOneWidget);

    // Interrupción (llamada) → pausa; reanudar requiere acción del usuario.
    await tester.runAsync(() async {
      audio.interrupt();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(controller.phase, LivePhase.paused);
    expect(find.textContaining('llamada'), findsOneWidget);
    expect(server.last.sentJson.any((m) => m['type'] == 'pause'), isTrue);
    await tester.runAsync(() async {
      await tester.tap(find.text('Reanudar'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(controller.phase, LivePhase.live);

    // Finalizar con confirmación.
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Finalizar la sesión?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Finalizar').last);
    for (var i = 0; i < 10 && controller.phase != LivePhase.ended; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(controller.phase, LivePhase.ended);
    expect(audio.started, isFalse);
    expect(find.text('Sesión finalizada.'), findsOneWidget);
    account.dispose();
  });

  testWidgets('sin permiso de micrófono muestra explicación y no conecta', (tester) async {
    SharedPreferences.setMockInitialValues({'uiLocale': 'es'});
    final settings = await SettingsController.load();
    final auth = FakeAuth();
    final account = AccountController(auth: auth, api: ApiClient(baseUrl: 'http://x', token: auth.accessToken), purchases: PurchasesService());
    final server = FakeServer();
    final audio = FakeAudio()..permission = false;
    final controller = LiveController(
      audio: audio,
      connectionFactory: (p, l) => LiveConnection(uri: Uri.parse('ws://x'), tokenProvider: auth.accessToken, params: p, lastSeq: l, channelFactory: server.connect),
      source: Lang.es,
      target: null,
      save: false,
      keepScreenOn: false,
    );
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider.value(value: settings), ChangeNotifierProvider.value(value: account)],
      child: appEs(LiveScreen(source: Lang.es, display: DisplayMode.original, save: false, controller: controller)),
    ));
    await tester.runAsync(() async {
      await tester.tap(find.text('Iniciar'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.textContaining('Sin permiso de micrófono'), findsOneWidget);
    expect(server.channels, isEmpty);
    account.dispose();
  });
}
