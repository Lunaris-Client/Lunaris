import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

class AppBadgeService {
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid || Platform.isMacOS);

  static Future<void> updateCount(int count) async {
    if (!isSupported) return;
    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) return;
      if (count > 0) {
        FlutterAppBadger.updateBadgeCount(count);
      } else {
        FlutterAppBadger.removeBadge();
      }
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (!isSupported) return;
    try {
      FlutterAppBadger.removeBadge();
    } catch (_) {}
  }
}
