import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/account_controller.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import '../common.dart';

/// Muestra cuánto consumirá ANTES de procesar y pide confirmación.
/// Devuelve el resultado o null si se canceló / no se permitió.
Future<Map<String, dynamic>?> translateWithEstimate(BuildContext context, {required Lang source, required Lang target, String? text, String? transcriptId}) async {
  final s = S.of(context);
  final api = context.read<ApiClient>();
  final account = context.read<AccountController>();
  try {
    final est = await api.estimate(source, target, text: text, transcriptId: transcriptId);
    if (!context.mounted) return null;
    if (!est.allowed) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(s.t('estimate_not_allowed', {'reason': s.t('reason_${est.reason ?? 'empty'}')})),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(s.t('close')))],
        ),
      );
      return null;
    }
    final ok = await confirmDialog(
      context,
      s.t('estimate_msg', {'cost': formatMinutes(est.costSeconds), 'remaining': formatMinutes(est.remainingSeconds), 'chars': '${est.chars}'}),
    );
    if (!ok || !context.mounted) return null;
    final r = await api.translate(source, target, text: text, transcriptId: transcriptId);
    await account.refresh();
    return r;
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, errorMessage(s, e.isNetwork ? 'network' : e.code));
    return null;
  }
}

class TextTranslateScreen extends StatefulWidget {
  const TextTranslateScreen({super.key});
  @override
  State<TextTranslateScreen> createState() => _TextTranslateScreenState();
}

class _TextTranslateScreenState extends State<TextTranslateScreen> {
  final _text = TextEditingController();
  Lang _source = Lang.en;
  String? _result;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('text_translate'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(s.t('direction'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<Lang>(
              segments: [ButtonSegment(value: Lang.en, label: Text(s.t('en_to_es'))), ButtonSegment(value: Lang.es, label: Text(s.t('es_to_en')))],
              selected: {_source},
              onSelectionChanged: (v) => setState(() => _source = v.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 14,
              maxLength: 20000,
              decoration: InputDecoration(labelText: s.t('paste_text'), border: const OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      final r = await translateWithEstimate(context, source: _source, target: _source.other, text: _text.text);
                      if (mounted) {
                        setState(() {
                          _busy = false;
                          if (r != null) _result = r['text'] as String?;
                        });
                      }
                    },
              child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.t('calculate_cost')),
            ),
            if (_result != null) ...[
              SectionTitle(s.t('result')),
              SelectableText(_result!, style: const TextStyle(fontSize: 18)),
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(s.t('copy')),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _result!));
                  if (context.mounted) showSnack(context, s.t('copied'));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
