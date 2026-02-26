import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OfflineAction {
  final String id;
  final String serverUrl;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const OfflineAction({
    required this.id,
    required this.serverUrl,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverUrl': serverUrl,
    'type': type,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    id: json['id'] as String,
    serverUrl: json['serverUrl'] as String,
    type: json['type'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class OfflineActionQueue {
  static const _key = 'offline_action_queue';
  final SharedPreferences _prefs;

  OfflineActionQueue(this._prefs);

  List<OfflineAction> getAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => OfflineAction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> enqueue(OfflineAction action) async {
    final actions = getAll();
    actions.add(action);
    await _save(actions);
  }

  Future<void> remove(String id) async {
    final actions = getAll();
    actions.removeWhere((a) => a.id == id);
    await _save(actions);
  }

  Future<void> clearAll() async {
    await _prefs.remove(_key);
  }

  int get pendingCount => getAll().length;

  Future<void> _save(List<OfflineAction> actions) async {
    final json = jsonEncode(actions.map((a) => a.toJson()).toList());
    await _prefs.setString(_key, json);
  }
}
