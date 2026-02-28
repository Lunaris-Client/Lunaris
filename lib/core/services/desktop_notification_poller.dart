import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lunaris/core/services/notification_poller.dart';

class DesktopNotificationPoller {
  static final DesktopNotificationPoller _instance =
      DesktopNotificationPoller._();
  factory DesktopNotificationPoller() => _instance;
  DesktopNotificationPoller._();

  Timer? _timer;
  bool _polling = false;

  static const _interval = Duration(seconds: 60);

  static bool get isSupported =>
      !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

  void start() {
    if (!isSupported) return;
    stop();
    _poll();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      await NotificationPoller.pollAllServers();
    } catch (e) {
      debugPrint('[DesktopPoller] error: $e');
    } finally {
      _polling = false;
    }
  }
}
