import 'package:flutter/material.dart';
import 'package:lunaris/core/models/theme_settings.dart';
import 'package:lunaris/ui/theme/discourse_colors.dart';

class LunarisTheme {
  static const defaultSeedColor = ThemeSettings.defaultSeedColor;

  static ThemeData light({Color? seedColor, DiscourseColors? serverColors}) {
    return _build(Brightness.light, seedColor ?? defaultSeedColor, serverColors);
  }

  static ThemeData dark({Color? seedColor, DiscourseColors? serverColors}) {
    return _build(Brightness.dark, seedColor ?? defaultSeedColor, serverColors);
  }

  static ThemeData _build(Brightness brightness, Color seed, DiscourseColors? serverColors) {
    final ColorScheme colorScheme;
    AppBarTheme? appBarTheme;

    if (serverColors != null) {
      colorScheme = serverColors.toFlutterColorScheme(brightness);
      appBarTheme = serverColors.toAppBarTheme();
    } else {
      final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
      colorScheme = base.copyWith(
        primary: seed,
        onPrimary: ThemeData.estimateBrightnessForColor(seed) == Brightness.light
            ? Colors.black
            : Colors.white,
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: appBarTheme,
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
          minimumSize: const Size(88, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
