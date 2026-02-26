import 'package:dio/dio.dart';
import 'package:lunaris/core/models/server_info.dart';

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

  String _normalizeUrl(String url) {
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
    final url = _normalizeUrl(rawUrl);

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

  String? _resolveUrl(String baseUrl, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }
}
