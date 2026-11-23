import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api_client.dart';
import '../common.dart';
import 'listener_screen.dart';

/// Normaliza lo escrito o escaneado: acepta minúsculas, espacios, guiones y
/// el prefijo del QR («FAITHBRIDGE:»). Devuelve XXXX-XXXX o null.
String? normalizeJoinCode(String input) {
  final raw = input.trim().toUpperCase().replaceFirst(RegExp(r'^FAITHBRIDGE:'), '').replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$').hasMatch(raw)) return null;
  return '${raw.substring(0, 4)}-${raw.substring(4)}';
}

/// Unirse como asistente con código o QR. No requiere cuenta ni micrófono.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join(String input) async {
    final s = S.of(context);
    final code = normalizeJoinCode(input);
    if (code == null) {
      setState(() => _error = s.t('join_invalid_code'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await context.read<ApiClient>().joinChurch(code);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ListenerScreen(join: r)));
    } on ApiException catch (e) {
      setState(() => _error = switch (e.code) {
            'invalid_code' => s.t('join_invalid_code'),
            'session_full' => s.t('join_session_full'),
            'rate_limited' => s.t('err_rate_limited'),
            'church_mode_disabled' => s.t('join_disabled'),
            _ => errorMessage(s, e.isNetwork ? 'network' : e.code),
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanScreen()));
    if (value != null && mounted) {
      _code.text = normalizeJoinCode(value) ?? value;
      await _join(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('join_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(s.t('listener_no_mic'), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              style: const TextStyle(fontSize: 26, letterSpacing: 3),
              decoration: InputDecoration(labelText: s.t('join_code_label'), border: const OutlineInputBorder()),
              onSubmitted: _join,
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : () => _join(_code.text),
              child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.t('join_button')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _busy ? null : _scan, icon: const Icon(Icons.qr_code_scanner), label: Text(s.t('scan_qr'))),
          ],
        ),
      ),
    );
  }
}

/// Escáner de QR: la cámara se activa solo al abrir esta pantalla.
class _ScanScreen extends StatefulWidget {
  const _ScanScreen();
  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('scan_qr'))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(s.t('scan_qr_hint'))),
        Expanded(
          child: MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && normalizeJoinCode(v) != null) {
                  _done = true;
                  Navigator.of(context).pop(v);
                  return;
                }
              }
            },
          ),
        ),
      ]),
    );
  }
}
