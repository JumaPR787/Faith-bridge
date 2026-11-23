import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Preferencias locales del dispositivo (no contienen datos sensibles).
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsController> load() async => SettingsController(await SharedPreferences.getInstance());

  bool get onboardingDone => _prefs.getBool('onboardingDone') ?? false;
  String get uiLocale => _prefs.getString('uiLocale') ?? _deviceDefault();
  double get captionScale => _prefs.getDouble('captionScale') ?? 1.0;
  bool get highContrast => _prefs.getBool('highContrast') ?? false;
  ThemeMode get themeMode => ThemeMode.values[_prefs.getInt('themeMode') ?? ThemeMode.system.index];
  bool get keepScreenOn => _prefs.getBool('keepScreenOn') ?? true;
  Lang get lastSource => Lang.parse(_prefs.getString('lastSource') ?? 'en');
  DisplayMode get lastDisplay => DisplayMode.values[_prefs.getInt('lastDisplay') ?? DisplayMode.both.index];
  bool get lastSave => _prefs.getBool('lastSave') ?? false;

  static String _deviceDefault() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == 'en' ? 'en' : 'es';
  }

  Future<void> _set(Future<bool> f) async {
    await f;
    notifyListeners();
  }

  Future<void> completeOnboarding() => _set(_prefs.setBool('onboardingDone', true));
  Future<void> setUiLocale(String v) => _set(_prefs.setString('uiLocale', v));
  Future<void> setCaptionScale(double v) => _set(_prefs.setDouble('captionScale', v.clamp(0.8, 2.5)));
  Future<void> setHighContrast(bool v) => _set(_prefs.setBool('highContrast', v));
  Future<void> setThemeMode(ThemeMode v) => _set(_prefs.setInt('themeMode', v.index));
  Future<void> setKeepScreenOn(bool v) => _set(_prefs.setBool('keepScreenOn', v));
  Future<void> rememberSetup(Lang source, DisplayMode display, bool save) async {
    await _prefs.setString('lastSource', source.code);
    await _prefs.setInt('lastDisplay', display.index);
    await _prefs.setBool('lastSave', save);
    notifyListeners();
  }

  /// Al eliminar la cuenta o cerrar sesión: se conservan solo preferencias visuales.
  Future<void> clearPersonal() async {
    await _prefs.remove('lastSource');
    await _prefs.remove('lastDisplay');
    await _prefs.remove('lastSave');
    notifyListeners();
  }
}
