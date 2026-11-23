import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';
import 'data/account_controller.dart';
import 'data/api_client.dart';
import 'data/auth_service.dart';
import 'data/purchases_service.dart';
import 'data/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  final missing = AppConfig.missing();
  if (missing.isNotEmpty) {
    runApp(ConfigErrorApp(missing: missing));
    return;
  }
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabasePublishableKey);
  final auth = SupabaseAuthGateway(Supabase.instance.client);
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl, token: auth.accessToken);
  final account = AccountController(auth: auth, api: api, purchases: PurchasesService());
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: account),
      Provider.value(value: api),
    ],
    child: const FaithBridgeApp(),
  ));
  await account.refresh();
}

/// Se muestra si la compilación no recibió la configuración necesaria.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.missing});
  final List<String> missing;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Configuración incompleta / Missing configuration:\n\n${missing.join('\n')}\n\nVer README: --dart-define'),
            ),
          ),
        ),
      );
}
