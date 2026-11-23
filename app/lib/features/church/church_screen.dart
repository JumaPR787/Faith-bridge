import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/account_controller.dart';
import 'join_screen.dart';
import 'orgs_screen.dart';

/// Menú del modo iglesia. Si el servidor lo tiene deshabilitado, lo dice con
/// claridad: no simula una función que no está disponible.
class ChurchScreen extends StatelessWidget {
  const ChurchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final enabled = context.watch<AccountController>().churchEnabled;
    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: Text(s.t('church_title'))),
      body: enabled
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    minVerticalPadding: 14,
                    leading: const Icon(Icons.qr_code_scanner, size: 32),
                    title: Text(s.t('church_join')),
                    subtitle: Text(s.t('church_join_desc')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => go(const JoinScreen()),
                  ),
                ),
                Card(
                  child: ListTile(
                    minVerticalPadding: 14,
                    leading: const Icon(Icons.campaign_outlined, size: 32),
                    title: Text(s.t('church_organize')),
                    subtitle: Text(s.t('church_organize_desc')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => go(const OrgsScreen()),
                  ),
                ),
              ],
            )
          : Padding(
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
