import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/settings_controller.dart';
import '../../domain/models.dart';
import 'live_screen.dart';

/// Selección manual del idioma de origen, de lo que se muestra y de si se guarda.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late Lang _source;
  late DisplayMode _display;
  late bool _save;

  @override
  void initState() {
    super.initState();
    final st = context.read<SettingsController>();
    _source = st.lastSource;
    _display = st.lastDisplay;
    _save = st.lastSave;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    String langName(Lang l) => l == Lang.en ? s.t('english') : s.t('spanish');
    return Scaffold(
      appBar: AppBar(title: Text(s.t('setup_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(header: true, child: Text(s.t('speaker_language'), style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 8),
            SegmentedButton<Lang>(
              segments: [for (final l in Lang.values) ButtonSegment(value: l, label: Text(langName(l)))],
              selected: {_source},
              onSelectionChanged: (v) => setState(() => _source = v.first),
            ),
            const SizedBox(height: 24),
            Semantics(header: true, child: Text(s.t('what_to_show'), style: Theme.of(context).textTheme.titleMedium)),
            RadioGroup<DisplayMode>(
              groupValue: _display,
              onChanged: (v) => setState(() => _display = v ?? _display),
              child: Column(children: [
                RadioListTile(value: DisplayMode.original, title: Text(s.t('show_original'))),
                RadioListTile(value: DisplayMode.translation, title: Text(s.t('show_translation'))),
                RadioListTile(value: DisplayMode.both, title: Text(s.t('show_both'))),
              ]),
            ),
            if (_display != DisplayMode.original)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('${s.t('translate_to')}: ${langName(_source.other)}', style: Theme.of(context).textTheme.bodyLarge),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _save,
              onChanged: (v) => setState(() => _save = v),
              title: Text(s.t('save_transcript')),
              subtitle: Text(s.t('save_transcript_desc')),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(leading: const Icon(Icons.hearing), title: Text(s.t('ambient_notice'))),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.mic),
              label: Text(s.t('start')),
              onPressed: () async {
                await context.read<SettingsController>().rememberSetup(_source, _display, _save);
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                  builder: (_) => LiveScreen(source: _source, display: _display, save: _save),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
