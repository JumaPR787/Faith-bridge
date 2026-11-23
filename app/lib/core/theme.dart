import 'package:material_ui/material_ui.dart';

/// Temas sobrios para un servicio religioso: fondos tranquilos, buen
/// contraste y variantes de alto contraste para claro y oscuro.
class AppTheme {
  static const _seed = Color(0xFF2F4A6D); // azul sobrio

  static ThemeData build({required Brightness brightness, required bool highContrast}) {
    final ColorScheme scheme;
    if (highContrast) {
      scheme = brightness == Brightness.dark
          ? const ColorScheme.highContrastDark(primary: Color(0xFFFFE066), onPrimary: Colors.black, surface: Colors.black, onSurface: Colors.white)
          : const ColorScheme.highContrastLight(primary: Color(0xFF002B5C), onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black);
    } else {
      scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    }
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      // Objetivos táctiles amplios (≥ 48 dp) para uso durante el servicio.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52), textStyle: const TextStyle(fontSize: 17)),
      ),
    );
  }
}
