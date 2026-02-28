import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:lunaris/core/models/notification_settings.dart';
import 'package:lunaris/core/services/local_notification_service.dart';

const _taskName = 'lunaris_notification_check';
const _taskUniqueName = 'lunaris_bg_notification_poll';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return true;
    try {
      await _pollAllServers();
    } catch (_) {}
    return true;
  });
}

Future<void> _pollAllServers() async {
  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    ),
  );
  final notifService = LocalNotificationService();
  await notifService.initialize();

  final raw = prefs.getString('server_accounts');
  if (raw == null) return;

  final accounts = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  for (final account in accounts) {
    if (account['isAuthenticated'] != true) continue;

    final serverUrl = account['serverUrl'] as String;
    final siteName = account['siteName'] as String? ?? serverUrl;

    final settingsRaw = prefs.getString('notification_settings_$serverUrl');
    final settings =
        settingsRaw != null
            ? NotificationSettings.decode(settingsRaw)
            : const NotificationSettings();

    if (!settings.enabled ||
        settings.isInQuietHours ||
        !settings.showSystemNotifications) {
      continue;
    }

    final apiKey = await secureStorage.read(key: 'api_key_$serverUrl');
    if (apiKey == null) continue;

    try {
      final response = await dio.get(
        '$serverUrl/notifications.json',
        queryParameters: {'recent': true},
        options: Options(headers: {'User-Api-Key': apiKey}),
      );
      final data = response.data as Map<String, dynamic>;
      final notifications = data['notifications'] as List? ?? [];
      final unreadCount = notifications.where((n) => n['read'] != true).length;

      final lastKey = 'bg_last_unread_$serverUrl';
      final lastUnread = prefs.getInt(lastKey) ?? 0;

      if (unreadCount > lastUnread && unreadCount > 0) {
        await notifService.show(
          title: siteName,
          body:
              '$unreadCount unread notification${unreadCount == 1 ? '' : 's'}',
          payload: NotificationPayload(
            serverUrl: serverUrl,
            type: 'notification',
          ),
        );
      }

      await prefs.setInt(lastKey, unreadCount);
    } catch (_) {}
  }
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
