import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppBadgeService {
  static const _channel = MethodChannel('app_badge');

  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  static Future<void> updateCount(int count) async {
    if (!isSupported) return;
    try {
      if (count > 0) {
        await _channel.invokeMethod('updateBadgeCount', count);
      } else {
        await _channel.invokeMethod('removeBadge');
      }
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod('removeBadge');
    } catch (_) {}
  }
}
