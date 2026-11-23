import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/account_controller.dart';
import '../../domain/models.dart';
import '../common.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final account = context.watch<AccountController>();
    final q = account.quota;
    String fmt(DateTime? d) => d == null ? '—' : DateFormat.yMMMd(s.code).format(d);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('subscription'))),
      body: RefreshIndicator(
        onRefresh: account.refresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(title: Text(s.t('status')), subtitle: Text(s.t('status_${q.status}'))),
            ListTile(title: Text(s.t('minutes_used')), subtitle: Text('${formatMinutes(q.usedSeconds)} / ${q.quotaSeconds ~/ 60} min')),
            ListTile(title: Text(s.t('minutes_left')), subtitle: Text(formatMinutes(q.remainingSeconds))),
            ListTile(title: Text(q.isTrial ? s.t('trial_ends_on') : s.t('renews_on')), subtitle: Text(fmt(q.periodEnd))),
            const SizedBox(height: 8),
            Text(s.t('when_out_of_minutes')),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(s.t('manage_in_store')),
              onPressed: () async {
                final url = await account.purchases.managementUrl();
                if (url != null) await openUrl(url);
              },
            ),
            const SizedBox(height: 12),
            Text(s.t('how_to_cancel'), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
