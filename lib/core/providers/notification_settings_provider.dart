import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/core/models/notification_settings.dart';
import 'package:lunaris/core/providers/providers.dart';

final notificationSettingsProvider = StateNotifierProvider.family<
  NotificationSettingsNotifier,
  NotificationSettings,
  String
>(
  (ref, serverUrl) => NotificationSettingsNotifier(
    ref.watch(sharedPreferencesProvider),
    serverUrl,
  ),
);

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final SharedPreferences _prefs;
  final String _serverUrl;

  static String _key(String serverUrl) => 'notification_settings_$serverUrl';

  NotificationSettingsNotifier(this._prefs, this._serverUrl)
    : super(const NotificationSettings()) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key(_serverUrl));
    if (raw != null) {
      try {
        state = NotificationSettings.decode(raw);
      } catch (_) {}
    }
  }

  Future<void> update(NotificationSettings settings) async {
    state = settings;
    await _prefs.setString(_key(_serverUrl), settings.encode());
  }
}
