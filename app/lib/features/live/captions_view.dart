import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../domain/models.dart';
import '../../domain/transcript_store.dart';

/// Lista de subtítulos (confirmados + provisional) compartida por la pantalla
/// en vivo (modo personal / organizador) y la de oyentes del modo iglesia.
class CaptionsView extends StatelessWidget {
  const CaptionsView({
    super.key,
    required this.store,
    required this.display,
    required this.scale,
    required this.controller,
    this.emptyText,
    this.footer,
  });

  final TranscriptStore store;
  final DisplayMode display;
  final double scale;
  final ScrollController controller;
  final String? emptyText;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final segments = store.segments;
    final interim = store.interim;
    final base = theme.textTheme.headlineSmall!.copyWith(fontSize: 22 * scale, height: 1.35);
    final secondary = base.copyWith(fontSize: 18 * scale, color: theme.colorScheme.onSurfaceVariant);
    final showOriginal = display != DisplayMode.translation;
    final showTranslation = display != DisplayMode.original;

    final children = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isLast = i == segments.length - 1;
      final parts = <Widget>[];
      if (showTranslation) {
        final String text;
        final TextStyle style;
        switch (seg.translationState) {
          case TranslationState.ok:
            text = seg.translation!;
            style = base;
          case TranslationState.failed:
            text = s.t('translation_unavailable');
            style = secondary.copyWith(fontStyle: FontStyle.italic);
          case TranslationState.pending:
          case TranslationState.none:
            text = s.t('translating');
            style = secondary.copyWith(fontStyle: FontStyle.italic);
        }
        parts.add(Text(text, style: style));
      }
      if (showOriginal) {
        parts.add(Text(seg.text, style: showTranslation ? secondary : base));
      }
      children.add(Semantics(
        liveRegion: isLast,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: parts),
        ),
      ));
    }
    if (interim != null && showOriginal) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(interim, style: secondary.copyWith(fontStyle: FontStyle.italic)),
      ));
    }
    if (footer != null) children.add(footer!);
    if (segments.isEmpty && interim == null && footer == null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(emptyText ?? s.t('listening'), textAlign: TextAlign.center, style: secondary)),
      );
    }
    return ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: children);
  }
}
