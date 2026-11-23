import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api_client.dart';
import '../../data/settings_controller.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../translate/text_translate_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<TranscriptSummary>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = context.read<ApiClient>().transcripts());

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('history'))),
      body: FutureBuilder<List<TranscriptSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(s.t('error_network')), TextButton(onPressed: _load, child: Text(s.t('retry')))]));
          }
          final items = snap.data!;
          if (items.isEmpty) return Center(child: Text(s.t('history_empty')));
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = items[i];
                final date = DateFormat.yMMMd(s.code).add_jm().format(t.createdAt);
                final langs = t.targetLang == null ? t.sourceLang.code.toUpperCase() : '${t.sourceLang.code.toUpperCase()} → ${t.targetLang!.code.toUpperCase()}';
                return ListTile(
                  title: Text(date),
                  subtitle: Text('$langs · ${t.segmentCount}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TranscriptDetailScreen(id: t.id)));
                    _load();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class TranscriptDetailScreen extends StatefulWidget {
  const TranscriptDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<TranscriptDetailScreen> createState() => _TranscriptDetailScreenState();
}

class _TranscriptDetailScreenState extends State<TranscriptDetailScreen> {
  Future<TranscriptDetail>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = context.read<ApiClient>().transcript(widget.id));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scale = context.watch<SettingsController>().captionScale;
    return FutureBuilder<TranscriptDetail>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.t('history')),
            actions: [
              if (d != null)
                IconButton(
                  tooltip: s.t('copy'),
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    final text = d.segments.map((x) => [x.sourceText, if (x.translatedText != null) x.translatedText].join('\n')).join('\n\n');
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) showSnack(context, s.t('copied'));
                  },
                ),
              if (d != null)
                IconButton(
                  tooltip: s.t('delete'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await confirmDialog(context, s.t('delete_transcript_confirm'), confirmLabel: s.t('delete'), destructive: true)) return;
                    if (!context.mounted) return;
                    await context.read<ApiClient>().deleteTranscript(widget.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snap.hasError
                  ? Center(child: TextButton(onPressed: _load, child: Text(s.t('retry'))))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.translate),
                          label: Text(s.t('translate_this')),
                          onPressed: () async {
                            await translateWithEstimate(context, source: d!.summary.sourceLang, target: d.summary.sourceLang.other, transcriptId: widget.id);
                            _load();
                          },
                        ),
                        const SizedBox(height: 12),
                        for (final seg in d!.segments)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(seg.sourceText, style: TextStyle(fontSize: 18 * scale)),
                              if (seg.translatedText != null)
                                Text(seg.translatedText!, style: TextStyle(fontSize: 18 * scale, color: Theme.of(context).colorScheme.primary))
                              else if (seg.translationStatus == 'failed')
                                Text(s.t('translation_unavailable'), style: const TextStyle(fontStyle: FontStyle.italic)),
                            ]),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}
