/// Configuración por entorno, inyectada al compilar con --dart-define.
/// Ninguna clave privada vive en la app: solo URLs públicas, la clave
/// pública ("publishable") de Supabase y las claves PÚBLICAS del SDK de RevenueCat.
class AppConfig {
  static const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const revenueCatAppleKey = String.fromEnvironment('REVENUECAT_APPLE_KEY');
  static const revenueCatGoogleKey = String.fromEnvironment('REVENUECAT_GOOGLE_KEY');
  static const revenueCatOffering = String.fromEnvironment('REVENUECAT_OFFERING', defaultValue: 'default');
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_URL', defaultValue: 'https://example.com/faithbridge/privacy');
  static const termsUrl = String.fromEnvironment('TERMS_URL', defaultValue: 'https://example.com/faithbridge/terms');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@example.com');

  static bool get isProduction => env == 'production';

  static Uri get liveSocketUri {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/v1/live');
  }

  /// Faltan valores obligatorios para un entorno real.
  static List<String> missing() => [
        if (supabaseUrl.isEmpty) 'SUPABASE_URL',
        if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
        if (isProduction && !apiBaseUrl.startsWith('https://')) 'API_BASE_URL (https)',
      ];
}
