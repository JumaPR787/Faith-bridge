import 'dart:io';

import 'package:faithbridge/core/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada texto existe en español e inglés y no está vacío', () {
    for (final e in kStrings.entries) {
      expect(e.value.length, 2, reason: e.key);
      expect(e.value.every((v) => v.trim().isNotEmpty), isTrue, reason: e.key);
    }
  });

  test('toda clave usada en el código está definida', () {
    final re = RegExp(r"""\.t\(\s*'([a-z0-9_]+)'""");
    final missing = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        if (!kStrings.containsKey(m.group(1))) missing.add('${m.group(1)} (${f.path})');
      }
    }
    // Claves dinámicas usadas: status_<estado> y reason_<motivo>.
    for (final st in ['trial', 'active', 'cancelled_active', 'billing_issue', 'grace', 'expired', 'refunded', 'none']) {
      if (!kStrings.containsKey('status_$st')) missing.add('status_$st');
    }
    for (final k in ['plan_name_personal', 'plan_name_church', 'plan_name_none', 'role_owner', 'role_admin', 'role_member', 'session_scheduled', 'session_live', 'session_ended']) {
      if (!kStrings.containsKey(k)) missing.add(k);
    }
    for (final r in ['quota_exhausted', 'too_long', 'empty', 'no_entitlement']) {
      if (!kStrings.containsKey('reason_$r')) missing.add('reason_$r');
    }
    expect(missing, isEmpty);
  });

  test('la oferta de prueba incluye el precio de la tienda, no uno fijo', () {
    final es = S('es').t('trial_offer', {'price': r'US$ 5.99'});
    expect(es, contains(r'US$ 5.99'));
    expect(es, contains('120 minutos'));
    expect(kStrings['trial_offer']!.every((v) => v.contains('{price}')), isTrue);
  });
}
