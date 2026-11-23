import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../common.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget q(String key) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(s.t(key), style: Theme.of(context).textTheme.bodyLarge));
    return Scaffold(
      appBar: AppBar(title: Text(s.t('help'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          q('help_internet'),
          q('help_background'),
          q('help_accuracy'),
          q('help_bible'),
          q('ambient_notice'),
          q('minute_counting'),
          q('how_to_cancel'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined),
            title: Text(s.t('help_contact')),
            subtitle: const Text(AppConfig.supportEmail),
            onTap: () => openUrl('mailto:${AppConfig.supportEmail}'),
          ),
        ],
      ),
    );
  }
}
