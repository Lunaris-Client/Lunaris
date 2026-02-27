import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/storage/server_storage.dart';
import 'package:lunaris/core/storage/site_cache.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/models/site_data.dart';
import 'package:lunaris/core/services/site_bootstrap_service.dart';
import 'package:lunaris/core/services/upload_service.dart';

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

final activeServerIdProvider =
    StateNotifierProvider<ActiveServerNotifier, String?>((ref) {
  return ActiveServerNotifier(ref.watch(sharedPreferencesProvider));
});

class ActiveServerNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const _key = 'active_server_id';

  ActiveServerNotifier(this._prefs) : super(_prefs.getString(_key));

  Future<void> setActive(String? serverId) async {
    state = serverId;
    if (serverId != null) {
      await _prefs.setString(_key, serverId);
    } else {
      await _prefs.remove(_key);
    }
  }
}

final activeServerProvider = Provider<ServerAccount?>((ref) {
  final activeId = ref.watch(activeServerIdProvider);
  if (activeId == null) return null;
  final servers = ref.watch(serverAccountsProvider);
  try {
    return servers.firstWhere((s) => s.id == activeId);
  } catch (_) {
    return null;
  }
});

final siteCacheProvider = Provider<SiteCache>((ref) {
  return SiteCache();
});

final siteBootstrapServiceProvider = Provider<SiteBootstrapService>((ref) {
  return SiteBootstrapService(
    apiClient: ref.watch(discourseApiClientProvider),
    authService: ref.watch(authServiceProvider),
    cache: ref.watch(siteCacheProvider),
  );
});

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
  );
});

final siteDataProvider =
    AsyncNotifierProvider.family<SiteDataNotifier, SiteData?, String>(
  SiteDataNotifier.new,
);

class SiteDataNotifier extends FamilyAsyncNotifier<SiteData?, String> {
  @override
  Future<SiteData?> build(String arg) async {
    final service = ref.read(siteBootstrapServiceProvider);
    return service.bootstrap(arg);
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    final service = ref.read(siteBootstrapServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => service.fetchAndCache(arg));
    if (state.hasError && previous != null) {
      state = AsyncValue.data(previous);
    }
  }
}
