import 'package:flutter/material.dart';
import 'package:lunaris/core/models/theme_settings.dart';

class LunarisTheme {
  static const defaultSeedColor = ThemeSettings.defaultSeedColor;

  static ThemeData light({Color? seedColor}) {
    return _build(Brightness.light, seedColor ?? defaultSeedColor);
  }

  static ThemeData dark({Color? seedColor}) {
    return _build(Brightness.dark, seedColor ?? defaultSeedColor);
  }

  static ThemeData _build(Brightness brightness, Color seed) {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      brightness: brightness,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
