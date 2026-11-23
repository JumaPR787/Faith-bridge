import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/account_controller.dart';
import '../../data/purchases_service.dart';
import '../common.dart';
import 'subscription_screen.dart';

/// Planes Personal e Iglesia. Precio y elegibilidad vienen SIEMPRE de la tienda.
/// La oferta gratuita solo se muestra a usuarios elegibles. El plan Iglesia
/// solo aparece cuando el servidor tiene habilitado el modo iglesia.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _Offers {
  _Offers(this.personal, this.church, this.active);
  final PlanOffer? personal;
  final PlanOffer? church;
  final List<String> active;
}

class _PlansScreenState extends State<PlansScreen> {
  Future<_Offers>? _offers;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final p = context.read<AccountController>().purchases;
    final church = context.read<AccountController>().churchEnabled;
    Future<T?> safe<T>(Future<T?> f) => f.catchError((Object _) => null);
    _offers = Future.wait([
      safe(p.personalOffer()),
      church ? safe(p.churchOffer()) : Future<PlanOffer?>.value(null),
      p.activeProductIds().catchError((Object _) => const <String>[]),
    ]).then((r) => _Offers(r[0] as PlanOffer?, r[1] as PlanOffer?, r[2] as List<String>));
  }

  String _base(String id) => id.split(':').first;

  Future<void> _buy(PlanOffer offer, {String? replacing}) async {
    final s = S.of(context);
    final account = context.read<AccountController>();
    setState(() => _busy = true);
    final r = await account.purchases.buy(offer, replacingProductId: replacing);
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
    final plan = account.quota.hasAccess ? account.quota.plan : 'none';
    return Scaffold(
      appBar: AppBar(title: Text(s.t('plans_title'))),
      body: SafeArea(
        child: FutureBuilder<_Offers>(
          future: _offers,
          builder: (context, snap) {
            final loading = snap.connectionState != ConnectionState.done;
            final o = snap.data;
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
                // ───── Plan Personal ─────
                _PlanCard(
                  title: s.t('plan_personal'),
                  features: s.t('plan_personal_features'),
                  current: plan == 'personal',
                  children: [
                    if (plan == 'church') Text(s.t('church_includes_personal')),
                    if (plan == 'none' && loading) const Center(child: CircularProgressIndicator()),
                    if (plan == 'none' && !loading && o?.personal == null) Text(s.t('store_unavailable'), style: TextStyle(color: theme.colorScheme.error)),
                    if (plan == 'none' && o?.personal != null) ...[
                      Text(
                        o!.personal!.trialEligible ? s.t('trial_offer', {'price': o.personal!.priceString}) : s.t('no_trial_offer', {'price': o.personal!.priceString}),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (o.personal!.trialEligible) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t('trial_terms'))),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : () => _buy(o.personal!),
                        child: Text(o.personal!.trialEligible ? s.t('start_trial') : s.t('subscribe')),
                      ),
                    ],
                  ],
                ),
                // ───── Plan Iglesia (solo si el modo iglesia está habilitado) ─────
                if (account.churchEnabled)
                  _PlanCard(
                    title: s.t('plan_church'),
                    features: s.t('plan_church_features'),
                    subtitle: s.t('plan_church_who'),
                    current: plan == 'church',
                    children: [
                      if (plan != 'church' && loading) const Center(child: CircularProgressIndicator()),
                      if (plan != 'church' && !loading && o?.church == null) Text(s.t('store_unavailable'), style: TextStyle(color: theme.colorScheme.error)),
                      if (plan != 'church' && o?.church != null) ...[
                        Text(s.t('no_trial_offer', {'price': o!.church!.priceString}), style: theme.textTheme.titleMedium),
                        if (plan == 'personal') Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.t('church_upgrade_note'))),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  // Suscripción Personal activa que se reemplaza (cambio de plan, no una segunda suscripción).
                                  final personalBase = o.personal == null ? null : _base(o.personal!.productId);
                                  final replacing = plan == 'personal'
                                      ? o.active.where((id) => personalBase != null && _base(id) == personalBase).firstOrNull
                                      : null;
                                  _buy(o.church!, replacing: replacing);
                                },
                          child: Text(plan == 'personal' ? s.t('upgrade_to_church') : s.t('subscribe')),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 12),
                Text(s.t('minute_counting'), style: theme.textTheme.bodySmall),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.features, required this.current, required this.children, this.subtitle});
  final String title;
  final String features;
  final String? subtitle;
  final bool current;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: current ? RoundedRectangleBorder(side: BorderSide(color: theme.colorScheme.primary, width: 2), borderRadius: BorderRadius.circular(12)) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall))),
            if (current) Chip(label: Text(s.t('current_plan'))),
          ]),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: theme.textTheme.bodyMedium)),
          const SizedBox(height: 8),
          Text(features),
          if (children.isNotEmpty) const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }
}
