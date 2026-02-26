import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/storage/server_storage.dart';
import 'package:lunaris/core/models/server_account.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden at startup');
});

final discourseApiClientProvider = Provider<DiscourseApiClient>((ref) {
  return DiscourseApiClient();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final serverStorageProvider = Provider<ServerStorage>((ref) {
  return ServerStorage(ref.watch(sharedPreferencesProvider));
});

final serverAccountsProvider =
    StateNotifierProvider<ServerAccountsNotifier, List<ServerAccount>>((ref) {
  final storage = ref.watch(serverStorageProvider);
  return ServerAccountsNotifier(storage);
});

class ServerAccountsNotifier extends StateNotifier<List<ServerAccount>> {
  final ServerStorage _storage;

  ServerAccountsNotifier(this._storage) : super(_storage.loadAll());

  Future<void> add(ServerAccount account) async {
    await _storage.add(account);
    state = _storage.loadAll();
  }

  Future<void> update(ServerAccount account) async {
    await _storage.add(account);
    state = _storage.loadAll();
  }

  Future<void> remove(String serverUrl) async {
    await _storage.remove(serverUrl);
    state = _storage.loadAll();
  }
}
