import 'package:dio/dio.dart';
import 'package:lunaris/core/models/models.dart';

class DiscourseApiClient {
  late final Dio _dio;

  DiscourseApiClient({Dio? dio}) {
    _dio = dio ??
        Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Accept': 'application/json'},
        ));
  }

  String normalizeUrl(String url) {
    var normalized = url.trim();
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  Future<ServerInfo> probeServer(String rawUrl) async {
    final url = normalizeUrl(rawUrl);

    final response = await _dio.get('$url/site/basic-info.json');
    final data = response.data as Map<String, dynamic>;

    final logoUrl = data['logo_url'] as String?;
    final faviconUrl = data['favicon_url'] as String?;

    return ServerInfo(
      url: url,
      siteName: data['title'] as String? ?? url,
      description: data['description'] as String?,
      logoUrl: _resolveUrl(url, logoUrl),
      faviconUrl: _resolveUrl(url, faviconUrl),
      version: data['version'] as String?,
    );
  }

  Future<CurrentUser> fetchCurrentUser(
      String serverUrl, String apiKey) async {
    final response = await _dio.get(
      '$serverUrl/session/current.json',
      options: Options(headers: {'User-Api-Key': apiKey}),
    );
    final data = response.data as Map<String, dynamic>;
    final userData = data['current_user'] as Map<String, dynamic>;
    return CurrentUser.fromJson(userData);
  }

  Future<void> revokeApiKey(String serverUrl, String apiKey) async {
    await _dio.post(
      '$serverUrl/user-api-key/revoke',
      options: Options(headers: {'User-Api-Key': apiKey}),
    );
  }

  Future<Map<String, dynamic>> fetchSiteData(
      String serverUrl, String apiKey) async {
    final response = await _dio.get(
      '$serverUrl/site.json',
      options: Options(
        headers: {'User-Api-Key': apiKey},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  String? _resolveUrl(String baseUrl, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}
