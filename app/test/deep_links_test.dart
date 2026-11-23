import 'dart:async';

import 'package:faithbridge/data/api_client.dart';
import 'package:faithbridge/features/church/deep_links.dart';
import 'package:faithbridge/features/church/join_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  group('enlaces universales', () {
    test('el escáner acepta el enlace del QR', () {
      expect(normalizeJoinCode('https://faithbridge.example/j/ABCD2345'), 'ABCD-2345');
      expect(normalizeJoinCode('https://faithbridge.example/j/abcd-2345/'), 'ABCD-2345');
      expect(normalizeJoinCode('https://faithbridge.example/otra/ABCD2345'), isNull);
    });

    test('solo se aceptan enlaces https del dominio configurado con /j/CODIGO', () {
      const host = 'faithbridge.example';
      expect(joinCodeFromUri(Uri.parse('https://faithbridge.example/j/ABCD2345'), host), 'ABCD-2345');
      expect(joinCodeFromUri(Uri.parse('https://FAITHBRIDGE.example/j/ABCD2345'), host), 'ABCD-2345');
      expect(joinCodeFromUri(Uri.parse('https://evil.example/j/ABCD2345'), host), isNull);
      expect(joinCodeFromUri(Uri.parse('http://faithbridge.example/j/ABCD2345'), host), isNull);
      expect(joinCodeFromUri(Uri.parse('https://faithbridge.example/j/ABCD2345/extra'), host), isNull);
      expect(joinCodeFromUri(Uri.parse('https://faithbridge.example/j/NO'), host), isNull);
      expect(joinCodeFromUri(Uri.parse('https://faithbridge.example/j/ABCD2345'), ''), isNull);
    });
  });

  testWidgets('un enlace recibido abre «Unirme» con el código (una sola vez)', (t) async {
    final links = StreamController<Uri>();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(Provider.value(
      value: ApiClient(baseUrl: 'http://127.0.0.1:9', token: () async => null),
      child: MaterialApp(
        navigatorKey: nav,
        builder: (c, child) => DeepLinkListener(navigatorKey: nav, links: links.stream, host: 'faithbridge.example', child: child!),
        home: const Scaffold(body: Text('inicio')),
      ),
    ));
    links.add(Uri.parse('https://evil.example/j/ABCD2345'));
    await t.pump();
    expect(find.byType(JoinScreen), findsNothing);
    links.add(Uri.parse('https://faithbridge.example/j/ABCD2345'));
    links.add(Uri.parse('https://faithbridge.example/j/ABCD2345')); // duplicado del sistema
    await t.pumpAndSettle(); // animación de la nueva pantalla y el intento de unirse
    expect(find.byType(JoinScreen), findsOneWidget);
    // El duplicado no apila una segunda pantalla.
    expect(find.byType(JoinScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('ABCD-2345'), findsOneWidget);
    await links.close();
  });
}
