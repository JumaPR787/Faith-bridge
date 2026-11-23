import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';

/// Modo iglesia: fase 2. La pantalla explica honestamente que aún no está
/// disponible; no simula una función que no existe.
class ChurchScreen extends StatelessWidget {
  const ChurchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('church_title'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Chip(label: Text(s.t('coming_soon'))),
          const SizedBox(height: 16),
          Text(s.t('church_body'), style: Theme.of(context).textTheme.bodyLarge),
        ]),
      ),
    );
  }
}
