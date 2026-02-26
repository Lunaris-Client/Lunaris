import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class WindowStateService with WindowListener {
  static final WindowStateService _instance = WindowStateService._();
  factory WindowStateService() => _instance;
  WindowStateService._();

  static const _key = 'window_state';
  bool _initialized = false;

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;

    await windowManager.ensureInitialized();

    final saved = await _load();
    if (saved != null) {
      await windowManager.setBounds(saved);
    } else {
      await windowManager.setSize(const Size(1200, 800));
      await windowManager.center();
    }

    await windowManager.show();
    windowManager.addListener(this);
  }

  @override
  void onWindowResized() => _save();

  @override
  void onWindowMoved() => _save();

  Future<void> _save() async {
    if (!_initialized) return;
    try {
      final bounds = await windowManager.getBounds();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'x': bounds.left,
          'y': bounds.top,
          'w': bounds.width,
          'h': bounds.height,
        }),
      );
    } catch (_) {}
  }

  Future<Rect?> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Rect.fromLTWH(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
        (map['w'] as num).toDouble(),
        (map['h'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    windowManager.removeListener(this);
    _initialized = false;
  }
}
