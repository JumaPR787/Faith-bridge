import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/settings_controller.dart';
import '../common.dart';

/// Explicación de privacidad y permisos ANTES de pedir el micrófono.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget item(IconData icon, String key) => ListTile(
          leading: Icon(icon),
          title: Text(s.t(key)),
          contentPadding: EdgeInsets.zero,
        );
    return Scaffold(
      appBar: AppBar(title: Text(s.t('privacy_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            item(Icons.mic_none, 'privacy_mic'),
            item(Icons.graphic_eq, 'privacy_audio'),
            item(Icons.translate, 'privacy_translation'),
            item(Icons.history, 'privacy_saving'),
            item(Icons.block, 'privacy_training'),
            item(Icons.verified_user_outlined, 'privacy_consent_others'),
            TextButton(onPressed: () => openUrl(AppConfig.privacyPolicyUrl), child: Text(s.t('privacy_read_policy'))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await context.read<SettingsController>().completeOnboarding();
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: Text(s.t('privacy_accept')),
            ),
          ],
        ),
      ),
    );
  }
}
