import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/account_controller.dart';
import '../../data/api_client.dart';
import '../../data/settings_controller.dart';
import '../common.dart';
import '../plans/subscription_screen.dart';
import 'glossary_screen.dart';
import 'help_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<SettingsController>();
    final account = context.read<AccountController>();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          SectionTitle(s.t('choose_ui_language')),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'es', label: Text('Español')), ButtonSegment(value: 'en', label: Text('English'))],
            selected: {st.uiLocale},
            onSelectionChanged: (v) {
              st.setUiLocale(v.first);
              context.read<ApiClient>().updateSettings(uiLocale: v.first).catchError((_) {});
            },
          ),
          SectionTitle(s.t('appearance')),
          Text('${s.t('text_size')}: ${(st.captionScale * 100).round()}%'),
          Slider(
            value: st.captionScale,
            min: 0.8,
            max: 2.5,
            divisions: 17,
            label: '${(st.captionScale * 100).round()}%',
            onChanged: st.setCaptionScale,
          ),
          Text('Aa — ${s.t('live_title')}', style: TextStyle(fontSize: 22 * st.captionScale)),
          SwitchListTile(value: st.highContrast, onChanged: st.setHighContrast, title: Text(s.t('high_contrast'))),
          ListTile(
            title: Text(s.t('theme')),
            trailing: DropdownButton<ThemeMode>(
              value: st.themeMode,
              onChanged: (v) => v == null ? null : st.setThemeMode(v),
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(s.t('theme_system'))),
                DropdownMenuItem(value: ThemeMode.light, child: Text(s.t('theme_light'))),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(s.t('theme_dark'))),
              ],
            ),
          ),
          SwitchListTile(value: st.keepScreenOn, onChanged: st.setKeepScreenOn, title: Text(s.t('keep_screen_on'))),
          SectionTitle(s.t('glossary')),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(s.t('glossary')),
            subtitle: Text(s.t('glossary_desc')),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GlossaryScreen())),
          ),
          SectionTitle(s.t('history')),
          ListTile(
            title: Text(s.t('retention')),
            trailing: DropdownButton<int>(
              value: null,
              hint: const Text('…'),
              items: [for (final d in [30, 90, 365]) DropdownMenuItem(value: d, child: Text('$d ${s.t('days')}'))],
              onChanged: (d) async {
                if (d == null) return;
                await context.read<ApiClient>().updateSettings(retentionDays: d);
                if (context.mounted) showSnack(context, '${s.t('retention')}: $d ${s.t('days')}');
              },
            ),
          ),
          SectionTitle(s.t('account')),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(s.t('subscription')),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen())),
          ),
          ListTile(leading: const Icon(Icons.help_outline), title: Text(s.t('help')), onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen()))),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(s.t('privacy_policy')), onTap: () => openUrl(AppConfig.privacyPolicyUrl)),
          ListTile(leading: const Icon(Icons.description_outlined), title: Text(s.t('terms')), onTap: () => openUrl(AppConfig.termsUrl)),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(s.t('sign_out')),
            onTap: () async {
              await account.signOut();
              await st.clearPersonal();
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text(s.t('delete_account'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () => _deleteAccount(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final s = S.of(context);
    final account = context.read<AccountController>();
    final st = context.read<SettingsController>();
    final manage = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.t('delete_account')),
        content: Text(s.t('delete_account_warning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: Text(s.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(c, 'manage'), child: Text(s.t('manage_in_store'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, 'delete'),
            child: Text(s.t('delete')),
          ),
        ],
      ),
    );
    if (manage == 'manage') {
      final url = await account.purchases.managementUrl();
      if (url != null) await openUrl(url);
      return;
    }
    if (manage != 'delete' || !context.mounted) return;
    try {
      await context.read<ApiClient>().deleteAccount();
      await account.signOut();
      await st.clearPersonal();
      if (context.mounted) {
        showSnack(context, s.t('delete_account_done'));
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } on ApiException {
      if (context.mounted) showSnack(context, s.t('error_network'));
    }
  }
}
