import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:lunaris/core/services/notification_poller.dart';

const _taskName = 'lunaris_notification_check';
const _taskUniqueName = 'lunaris_bg_notification_poll';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return true;
    try {
      await NotificationPoller.pollAllServers();
    } catch (_) {}
    return true;
  });
}

class BackgroundNotificationService {
  static bool _initialized = false;

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (!_isMobile || _initialized) return;

    await Workmanager().initialize(
      backgroundCallbackDispatcher,
      isInDebugMode: false,
    );
    _initialized = true;
  }

  static Future<void> register() async {
    if (!_isMobile || !_initialized) return;

    await Workmanager().registerPeriodicTask(
      _taskUniqueName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancel() async {
    if (!_isMobile || !_initialized) return;

    await Workmanager().cancelByUniqueName(_taskUniqueName);
  }
}
