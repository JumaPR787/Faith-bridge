import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import '../common.dart';

class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});
  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  Lang _source = Lang.en;
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = context.read<ApiClient>().glossary(_source, _source.other));

  Future<void> _add() async {
    final s = S.of(context);
    final a = TextEditingController();
    final b = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.t('add_term')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: a, maxLength: 80, decoration: InputDecoration(labelText: s.t('term_source'))),
          TextField(controller: b, maxLength: 80, decoration: InputDecoration(labelText: s.t('term_target'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('confirm'))),
        ],
      ),
    );
    if (ok != true || a.text.trim().isEmpty || b.text.trim().isEmpty || !mounted) return;
    try {
      await context.read<ApiClient>().addTerm(_source, _source.other, a.text.trim(), b.text.trim());
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.code == 'duplicate_term' ? '${a.text} ✓' : s.t('error_generic'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('glossary'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add), label: Text(s.t('add_term'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.t('glossary_desc')),
          const SizedBox(height: 12),
          SegmentedButton<Lang>(
            segments: [ButtonSegment(value: Lang.en, label: Text(s.t('en_to_es'))), ButtonSegment(value: Lang.es, label: Text(s.t('es_to_en')))],
            selected: {_source},
            onSelectionChanged: (v) {
              _source = v.first;
              _load();
            },
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              if (snap.hasError) return TextButton(onPressed: _load, child: Text(s.t('retry')));
              final custom = (snap.data!['custom'] as List).cast<Map<String, dynamic>>();
              final defaults = (snap.data!['defaults'] as List).cast<Map<String, dynamic>>();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionTitle(s.t('my_terms')),
                for (final t in custom)
                  ListTile(
                    title: Text('${t['sourceTerm']} → ${t['targetTerm']}'),
                    trailing: IconButton(
                      tooltip: s.t('delete'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await context.read<ApiClient>().deleteTerm(t['id'] as String);
                        _load();
                      },
                    ),
                  ),
                SectionTitle(s.t('default_terms')),
                for (final t in defaults) ListTile(dense: true, title: Text('${t['source']} → ${t['target']}')),
                const SizedBox(height: 80),
              ]);
            },
          ),
        ],
      ),
    );
  }
}
