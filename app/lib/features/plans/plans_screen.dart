import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/account_controller.dart';
import '../../data/purchases_service.dart';
import '../common.dart';
import 'subscription_screen.dart';

/// Planes y prueba. Precio y elegibilidad vienen SIEMPRE de la tienda.
/// La oferta gratuita solo se muestra a usuarios elegibles.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  Future<PlanOffer?>? _offer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _offer = context.read<AccountController>().purchases.personalOffer().catchError((Object _) => null);
  }

  Future<void> _buy(PlanOffer offer) async {
    final s = S.of(context);
    final account = context.read<AccountController>();
    setState(() => _busy = true);
    final r = await account.purchases.buy(offer);
    if (r == PurchaseOutcome.success) await account.syncAfterPurchase();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (r) {
      case PurchaseOutcome.success:
        showSnack(context, s.t('purchase_done'));
        Navigator.of(context).pop();
      case PurchaseOutcome.pending:
        showSnack(context, s.t('purchase_pending'));
      case PurchaseOutcome.failed:
        showSnack(context, s.t('error_generic'));
      case PurchaseOutcome.cancelled:
        break;
    }
  }

  Future<void> _restore() async {
    final s = S.of(context);
    final account = context.read<AccountController>();
    setState(() => _busy = true);
    bool found = false;
    try {
      found = await account.purchases.restore();
      await account.syncAfterPurchase();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, found && account.quota.hasAccess ? s.t('purchase_done') : s.t('restore_none'));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final account = context.watch<AccountController>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('plans_title'))),
      body: SafeArea(
        child: FutureBuilder<PlanOffer?>(
          future: _offer,
          builder: (context, snap) {
            final offer = snap.data;
            final loading = snap.connectionState != ConnectionState.done;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (account.quota.hasAccess)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(s.t('subscription')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen())),
                    ),
                  ),
                Text(s.t('plan_personal'), style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(s.t('plan_personal_features')),
                const SizedBox(height: 8),
                Text(s.t('minute_counting'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 20),
                if (loading) const Center(child: CircularProgressIndicator()),
                if (!loading && offer == null) Text(s.t('store_unavailable'), style: TextStyle(color: theme.colorScheme.error)),
                if (offer != null && !account.quota.hasAccess) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        offer.trialEligible ? s.t('trial_offer', {'price': offer.priceString}) : s.t('no_trial_offer', {'price': offer.priceString}),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (offer.trialEligible) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(s.t('trial_terms'))),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : () => _buy(offer),
                    child: Text(offer.trialEligible ? s.t('start_trial') : s.t('subscribe')),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _busy ? null : _restore, child: Text(s.t('restore'))),
                const SizedBox(height: 16),
                Text(s.t('how_to_cancel'), style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  TextButton(onPressed: () => openUrl(AppConfig.termsUrl), child: Text(s.t('terms'))),
                  TextButton(onPressed: () => openUrl(AppConfig.privacyPolicyUrl), child: Text(s.t('privacy_policy'))),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
