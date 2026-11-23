import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/strings.dart';

Future<void> openUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(BuildContext context, String message, {String? confirmLabel, bool destructive = false}) async {
  final s = S.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel ?? s.t('confirm')),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Mensaje legible para códigos de error del backend.
String errorMessage(S s, String? code) {
  switch (code) {
    case 'mic_denied':
      return s.t('mic_denied');
    case 'no_entitlement':
      return s.t('err_no_entitlement');
    case 'quota_exhausted':
      return s.t('ended_quota');
    case 'trial_already_used':
      return s.t('err_trial_used');
    case 'service_paused':
    case 'daily_budget_reached':
      return s.t('service_paused');
    case 'rate_limited':
      return s.t('err_rate_limited');
    case 'capacity':
      return s.t('err_capacity');
    case 'stt_unavailable':
      return s.t('ended_stt');
    case 'network':
      return s.t('error_network');
    default:
      return s.t('error_generic');
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      );
}
