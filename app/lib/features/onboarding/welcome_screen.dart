import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/settings_controller.dart';
import 'privacy_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Icon(Icons.closed_caption_outlined, size: 72, color: theme.colorScheme.primary, semanticLabel: 'FaithBridge'),
            const SizedBox(height: 16),
            Semantics(header: true, child: Text(s.t('welcome_title'), style: theme.textTheme.headlineMedium, textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            Text(s.t('welcome_body'), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.t('welcome_limits'))),
                ]),
              ),
            ),
            const SizedBox(height: 24),
            Text(s.t('choose_ui_language'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'es', label: Text('Español')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {settings.uiLocale},
              onSelectionChanged: (v) => settings.setUiLocale(v.first),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen())),
              child: Text(s.t('continue')),
            ),
          ],
        ),
      ),
    );
  }
}
