import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class DesktopTrayService with TrayListener {
  static final DesktopTrayService _instance = DesktopTrayService._();
  factory DesktopTrayService() => _instance;
  DesktopTrayService._();

  bool _initialized = false;

  static bool get isSupported =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> init({String tooltip = 'Lunaris'}) async {
    if (!isSupported || _initialized) return;
    _initialized = true;

    trayManager.addListener(this);
    await trayManager.setToolTip(tooltip);

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: 'Show Lunaris'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  Future<void> updateBadge(int count) async {
    if (!isSupported || !_initialized) return;
    final tooltip = count > 0 ? 'Lunaris ($count unread)' : 'Lunaris';
    await trayManager.setToolTip(tooltip);
  }

  void _showWindow() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'quit':
        windowManager.destroy();
    }
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    trayManager.removeListener(this);
    _initialized = false;
  }
}
