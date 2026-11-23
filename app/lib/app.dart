import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'data/account_controller.dart';
import 'data/settings_controller.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/welcome_screen.dart';

class FaithBridgeApp extends StatelessWidget {
  const FaithBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final account = context.watch<AccountController>();
    final Widget home;
    if (!settings.onboardingDone) {
      home = const WelcomeScreen();
    } else if (!account.signedIn) {
      home = const SignInScreen();
    } else {
      home = const HomeScreen();
    }
    return MaterialApp(
      title: 'FaithBridge',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.uiLocale),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings.themeMode,
      theme: AppTheme.build(brightness: Brightness.light, highContrast: settings.highContrast),
      darkTheme: AppTheme.build(brightness: Brightness.dark, highContrast: settings.highContrast),
      home: home,
    );
  }
}
