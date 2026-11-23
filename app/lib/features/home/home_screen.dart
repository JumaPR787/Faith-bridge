import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/account_controller.dart';
import '../../domain/models.dart';
import '../church/church_screen.dart';
import '../history/history_screen.dart';
import '../live/setup_screen.dart';
import '../plans/plans_screen.dart';
import '../settings/settings_screen.dart';
import '../translate/text_translate_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final account = context.watch<AccountController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('app_name')),
        actions: [
          IconButton(tooltip: s.t('settings'), icon: const Icon(Icons.settings_outlined), onPressed: () => _go(context, const SettingsScreen())),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: account.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            QuotaCard(quota: account.quota, onPlans: () => _go(context, const PlansScreen())),
            if (account.error == 'network')
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t('error_network'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
            if (!account.liveEnabled) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t('service_paused'))),
            const SizedBox(height: 16),
            _ModeTile(
              icon: Icons.mic_none,
              title: s.t('mode_personal'),
              subtitle: s.t('mode_personal_desc'),
              onTap: account.liveEnabled ? () => _go(context, account.quota.hasAccess ? const SetupScreen() : const PlansScreen()) : null,
            ),
            _ModeTile(
              icon: Icons.church_outlined,
              title: s.t('mode_church'),
              subtitle: s.t('mode_church_desc'),
              trailing: account.churchEnabled ? null : Chip(label: Text(s.t('coming_soon'))),
              onTap: () => _go(context, const ChurchScreen()),
            ),
            _ModeTile(icon: Icons.translate, title: s.t('text_translate'), subtitle: s.t('text_translate_desc'), onTap: () => _go(context, const TextTranslateScreen())),
            _ModeTile(icon: Icons.history, title: s.t('history'), onTap: () => _go(context, const HistoryScreen())),
            _ModeTile(icon: Icons.workspace_premium_outlined, title: s.t('plans'), onTap: () => _go(context, const PlansScreen())),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          minVerticalPadding: 14,
          leading: Icon(icon, size: 32),
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: trailing ?? const Icon(Icons.chevron_right),
          enabled: onTap != null,
          onTap: onTap,
        ),
      );
}

class QuotaCard extends StatelessWidget {
  const QuotaCard({super.key, required this.quota, required this.onPlans});
  final QuotaStatus quota;
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    if (!quota.hasAccess) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.t('no_plan'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            FilledButton(onPressed: onPlans, child: Text(s.t('see_plans'))),
          ]),
        ),
      );
    }
    final date = quota.periodEnd == null ? '' : DateFormat.yMMMd(s.code).format(quota.periodEnd!);
    final fraction = quota.quotaSeconds == 0 ? 0.0 : quota.remainingSeconds / quota.quotaSeconds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.t('minutes_left'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('${formatMinutes(quota.remainingSeconds)} / ${quota.quotaSeconds ~/ 60} min', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: fraction.clamp(0, 1), semanticsLabel: s.t('minutes_left')),
          const SizedBox(height: 8),
          if (date.isNotEmpty) Text('${quota.isTrial ? s.t('trial_ends_on') : s.t('renews_on')} $date'),
        ]),
      ),
    );
  }
}
