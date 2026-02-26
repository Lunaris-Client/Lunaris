import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/site_data.dart';
import 'package:lunaris/core/storage/site_cache.dart';

class SiteBootstrapService {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final SiteCache _cache;

  SiteBootstrapService({
    required DiscourseApiClient apiClient,
    required AuthService authService,
    required SiteCache cache,
  })  : _apiClient = apiClient,
        _authService = authService,
        _cache = cache;

  Future<SiteData?> loadCached(String serverUrl) async {
    final json = await _cache.load(serverUrl);
    if (json == null) return null;
    try {
      return SiteData.fromJson(json);
    } catch (_) {
      await _cache.clear(serverUrl);
      return null;
    }
  }

  Future<SiteData> fetchAndCache(String serverUrl) async {
    final apiKey = await _authService.loadApiKey(serverUrl);
    if (apiKey == null) throw StateError('No API key for $serverUrl');

    final raw = await _apiClient.fetchSiteData(serverUrl, apiKey);
    final siteData = SiteData.fromSiteJson(raw);
    await _cache.save(serverUrl, siteData.toJson());
    return siteData;
  }

  Future<SiteData> bootstrap(String serverUrl) async {
    final cached = await loadCached(serverUrl);
    if (cached != null) return cached;
    return fetchAndCache(serverUrl);
  }

  bool needsRefresh(SiteData data) => _cache.isStale(data.fetchedAt);
}
