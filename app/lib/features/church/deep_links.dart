import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import 'join_screen.dart';

/// Escucha enlaces universales (https://dominio/j/CODIGO) y abre «Unirme»
/// con el código. Funciona con la app cerrada (enlace inicial) o abierta.
class DeepLinkListener extends StatefulWidget {
  const DeepLinkListener({super.key, required this.navigatorKey, required this.child, this.links, this.host = AppConfig.appLinkHost});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final Stream<Uri>? links; // inyectable en pruebas
  final String host;

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  StreamSubscription<Uri>? _sub;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.links != null) {
      _sub = widget.links!.listen(_handle);
    } else if (widget.host.isNotEmpty) {
      final appLinks = AppLinks();
      unawaited(appLinks.getInitialLink().then((u) {
        if (u != null) _handle(u);
      }).catchError((Object _) {}));
      _sub = appLinks.uriLinkStream.listen(_handle, onError: (Object _) {});
    }
  }

  void _handle(Uri uri) {
    final code = joinCodeFromUri(uri, widget.host);
    if (code == null) return;
    // El sistema puede entregar el mismo enlace dos veces (inicial + stream).
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt) < const Duration(seconds: 5)) return;
    _lastCode = code;
    _lastAt = now;
    void open() => widget.navigatorKey.currentState?.push(MaterialPageRoute<void>(builder: (_) => JoinScreen(initialCode: code)));
    if (widget.navigatorKey.currentState != null) {
      open();
    } else {
      // Enlace inicial con la app recién abierta: espera al primer cuadro.
      WidgetsBinding.instance.addPostFrameCallback((_) => open());
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
