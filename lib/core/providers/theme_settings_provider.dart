import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/core/models/theme_settings.dart';
import 'package:lunaris/core/providers/providers.dart';

final themeSettingsProvider =
    StateNotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
  (ref) => ThemeSettingsNotifier(ref.watch(sharedPreferencesProvider)),
);

class ThemeSettingsNotifier extends StateNotifier<ThemeSettings> {
  final SharedPreferences _prefs;
  static const _key = 'theme_settings';

  ThemeSettingsNotifier(this._prefs) : super(const ThemeSettings()) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        state = ThemeSettings.decode(raw);
      } catch (_) {}
    }
  }

  Future<void> update(ThemeSettings settings) async {
    state = settings;
    await _prefs.setString(_key, settings.encode());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await update(state.copyWith(themeMode: mode));
  }

  Future<void> setUseServerColors(bool value) async {
    await update(state.copyWith(useServerColors: value));
  }

  Future<void> setCustomColor(String? hex) async {
    if (hex == null) {
      await update(state.copyWith(clearCustomColor: true));
    } else {
      await update(state.copyWith(customColorHex: hex));
    }
  }
}

final effectiveSeedColorProvider = Provider<Color>((ref) {
  final settings = ref.watch(themeSettingsProvider);

  if (settings.useServerColors) {
    final server = ref.watch(activeServerProvider);
    if (server != null) {
      final siteAsync = ref.watch(siteDataProvider(server.serverUrl));
      final siteData = siteAsync.valueOrNull;
      if (siteData != null) {
        final serverSeed = ThemeSettings.seedColorFromScheme(siteData.defaultLightColors);
        if (serverSeed != null) return serverSeed;
      }
    }
  }

  return settings.customColor ?? ThemeSettings.defaultSeedColor;
});
