import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/core/models/server_account.dart';

class ServerStorage {
  static const _key = 'server_accounts';

  final SharedPreferences _prefs;

  ServerStorage(this._prefs);

  List<ServerAccount> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ServerAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<ServerAccount> accounts) async {
    final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _prefs.setString(_key, json);
  }

  Future<void> add(ServerAccount account) async {
    final accounts = loadAll();
    accounts.removeWhere((a) => a.serverUrl == account.serverUrl);
    accounts.add(account);
    await saveAll(accounts);
  }

  Future<void> remove(String serverUrl) async {
    final accounts = loadAll();
    accounts.removeWhere((a) => a.serverUrl == serverUrl);
    await saveAll(accounts);
  }
}
