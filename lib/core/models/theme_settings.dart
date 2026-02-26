import 'dart:convert';

import 'package:flutter/material.dart';

class ThemeSettings {
  static const defaultSeedColor = Color(0xFF2196F3);

  final ThemeMode themeMode;
  final bool useServerColors;
  final String? customColorHex;

  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.useServerColors = true,
    this.customColorHex,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    bool? useServerColors,
    String? customColorHex,
    bool clearCustomColor = false,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      useServerColors: useServerColors ?? this.useServerColors,
      customColorHex: clearCustomColor ? null : (customColorHex ?? this.customColorHex),
    );
  }

  Color? get customColor => _colorFromHex(customColorHex);

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.index,
    'useServerColors': useServerColors,
    'customColorHex': customColorHex,
  };

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    final modeIndex = json['themeMode'] as int? ?? 0;
    return ThemeSettings(
      themeMode: ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)],
      useServerColors: json['useServerColors'] as bool? ?? true,
      customColorHex: json['customColorHex'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory ThemeSettings.decode(String raw) {
    return ThemeSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Color? colorFromHexMap(Map<String, String>? colors, String name) {
    if (colors == null) return null;
    return _colorFromHex(colors[name]);
  }

  static Color? seedColorFromScheme(Map<String, String>? colors) {
    return colorFromHexMap(colors, 'tertiary');
  }

  static Color? _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }
}
