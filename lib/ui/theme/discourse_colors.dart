import 'package:flutter/material.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class DiscourseColors {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color quaternary;
  final Color headerBackground;
  final Color headerPrimary;
  final Color danger;
  final Color success;
  final Color love;
  final Color highlight;

  const DiscourseColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.quaternary,
    required this.headerBackground,
    required this.headerPrimary,
    required this.danger,
    required this.success,
    required this.love,
    required this.highlight,
  });

  static DiscourseColors? fromColorMap(Map<String, String>? colors) {
    if (colors == null) return null;
    final p = tryParseHexColor(colors['primary']);
    final s = tryParseHexColor(colors['secondary']);
    final t = tryParseHexColor(colors['tertiary']);
    if (p == null || s == null || t == null) return null;
    return DiscourseColors(
      primary: p,
      secondary: s,
      tertiary: t,
      quaternary: tryParseHexColor(colors['quaternary']) ?? t,
      headerBackground: tryParseHexColor(colors['header_background']) ?? t,
      headerPrimary: tryParseHexColor(colors['header_primary']) ?? s,
      danger: tryParseHexColor(colors['danger']) ?? const Color(0xFFE45735),
      success: tryParseHexColor(colors['success']) ?? const Color(0xFF1CA551),
      love: tryParseHexColor(colors['love']) ?? const Color(0xFFFA6C8D),
      highlight: tryParseHexColor(colors['highlight']) ?? t,
    );
  }

  ColorScheme toFlutterColorScheme(Brightness brightness) {
    // In Discourse:
    //   primary   = main text color
    //   secondary = background / surface color
    //   tertiary  = links, buttons, active accent
    //
    // In Flutter M3:
    //   primary       = accent (buttons, FABs, active indicators)
    //   onPrimary     = text on accent
    //   surface       = page background
    //   onSurface     = main text
    //   error         = destructive actions

    final isLight = brightness == Brightness.light;
    final base = ColorScheme.fromSeed(
      seedColor: tertiary,
      brightness: brightness,
    );

    final onTertiary =
        ThemeData.estimateBrightnessForColor(tertiary) == Brightness.light
            ? Colors.black
            : Colors.white;
    final onDanger =
        ThemeData.estimateBrightnessForColor(danger) == Brightness.light
            ? Colors.black
            : Colors.white;

    return base.copyWith(
      primary: tertiary,
      onPrimary: onTertiary,
      primaryContainer: isLight
          ? Color.lerp(secondary, tertiary, 0.08)
          : Color.lerp(primary, tertiary, 0.15),
      onPrimaryContainer: isLight ? primary : secondary,
      surface: secondary,
      onSurface: primary,
      onSurfaceVariant: isLight
          ? Color.lerp(primary, secondary, 0.35)!
          : Color.lerp(secondary, primary, 0.35)!,
      surfaceContainerLowest: isLight
          ? secondary
          : Color.lerp(secondary, Colors.white, 0.03),
      surfaceContainerLow: isLight
          ? Color.lerp(secondary, primary, 0.03)
          : Color.lerp(secondary, Colors.white, 0.05),
      surfaceContainer: isLight
          ? Color.lerp(secondary, primary, 0.05)
          : Color.lerp(secondary, Colors.white, 0.07),
      surfaceContainerHigh: isLight
          ? Color.lerp(secondary, primary, 0.07)
          : Color.lerp(secondary, Colors.white, 0.09),
      surfaceContainerHighest: isLight
          ? Color.lerp(secondary, primary, 0.10)
          : Color.lerp(secondary, Colors.white, 0.12),
      secondary: quaternary,
      onSecondary: ThemeData.estimateBrightnessForColor(quaternary) == Brightness.light
          ? Colors.black
          : Colors.white,
      tertiary: highlight,
      onTertiary: ThemeData.estimateBrightnessForColor(highlight) == Brightness.light
          ? Colors.black
          : Colors.white,
      error: danger,
      onError: onDanger,
      outline: isLight
          ? Color.lerp(primary, secondary, 0.75)
          : Color.lerp(secondary, primary, 0.75),
      outlineVariant: isLight
          ? Color.lerp(primary, secondary, 0.88)
          : Color.lerp(secondary, primary, 0.88),
      inverseSurface: primary,
      onInverseSurface: secondary,
      inversePrimary: isLight
          ? Color.lerp(tertiary, Colors.white, 0.4)
          : Color.lerp(tertiary, Colors.black, 0.3),
    );
  }

  AppBarTheme toAppBarTheme() {
    final onHeader =
        ThemeData.estimateBrightnessForColor(headerBackground) == Brightness.light
            ? Colors.black
            : Colors.white;
    final foreground = headerPrimary == secondary ? onHeader : headerPrimary;
    return AppBarTheme(
      backgroundColor: headerBackground,
      foregroundColor: foreground,
      iconTheme: IconThemeData(color: foreground),
    );
  }

}
