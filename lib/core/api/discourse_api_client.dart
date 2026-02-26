import 'package:dio/dio.dart';
import 'package:lunaris/core/models/models.dart';

class DiscourseApiClient {
  late final Dio _dio;

  DiscourseApiClient({Dio? dio}) {
    _dio =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Accept': 'application/json'},
          ),
        );
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

  Future<CurrentUser> fetchCurrentUser(String serverUrl, String apiKey) async {
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
    String serverUrl,
    String apiKey,
  ) async {
    final response = await _dio.get(
      '$serverUrl/site.json',
      options: Options(
        headers: {'User-Api-Key': apiKey},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchTopicList(
    String serverUrl,
    String apiKey, {
    String filter = 'latest',
    int? page,
    int? categoryId,
    String? categorySlug,
    String? tagName,
    String? period,
  }) async {
    String path;
    if (categoryId != null && categorySlug != null && tagName != null) {
      path =
          '$serverUrl/tags/c/$categorySlug/$categoryId/$tagName/l/$filter.json';
    } else if (categoryId != null && categorySlug != null) {
      path = '$serverUrl/c/$categorySlug/$categoryId/l/$filter.json';
    } else if (tagName != null) {
      path = '$serverUrl/tag/$tagName/l/$filter.json';
    } else {
      path = '$serverUrl/$filter.json';
    }

    final queryParams = <String, dynamic>{};
    if (page != null && page > 0) queryParams['page'] = page;
    if (period != null && filter == 'top') queryParams['period'] = period;

    final response = await _dio.get(
      path,
      queryParameters: queryParams.isEmpty ? null : queryParams,
      options: Options(
        headers: {'User-Api-Key': apiKey},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchTopicDetail(
    String serverUrl,
    String apiKey,
    int topicId,
  ) async {
    final response = await _dio.get(
      '$serverUrl/t/$topicId.json',
      options: Options(
        headers: {'User-Api-Key': apiKey},
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchTopicPosts(
    String serverUrl,
    String apiKey,
    int topicId,
    List<int> postIds,
  ) async {
    final params = <String, dynamic>{};
    for (var i = 0; i < postIds.length; i++) {
      params['post_ids[$i]'] = postIds[i];
    }
    final response = await _dio.get(
      '$serverUrl/t/$topicId/posts.json',
      queryParameters: params,
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

  Options _authHeaders(String apiKey) =>
      Options(headers: {'User-Api-Key': apiKey});

  Future<Map<String, dynamic>> createPostAction(
    String serverUrl,
    String apiKey, {
    required int postId,
    required int postActionTypeId,
  }) async {
    final response = await _dio.post(
      '$serverUrl/post_actions',
      data: {'id': postId, 'post_action_type_id': postActionTypeId},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deletePostAction(
    String serverUrl,
    String apiKey, {
    required int postId,
    required int postActionTypeId,
  }) async {
    await _dio.delete(
      '$serverUrl/post_actions/$postId',
      queryParameters: {'post_action_type_id': postActionTypeId},
      options: _authHeaders(apiKey),
    );
  }

  Future<Map<String, dynamic>> createBookmark(
    String serverUrl,
    String apiKey, {
    required int bookmarkableId,
    String bookmarkableType = 'Post',
  }) async {
    final response = await _dio.post(
      '$serverUrl/bookmarks',
      data: {
        'bookmarkable_id': bookmarkableId,
        'bookmarkable_type': bookmarkableType,
      },
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteBookmark(
    String serverUrl,
    String apiKey,
    int bookmarkId,
  ) async {
    await _dio.delete(
      '$serverUrl/bookmarks/$bookmarkId',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> setTopicNotificationLevel(
    String serverUrl,
    String apiKey,
    int topicId,
    int notificationLevel,
  ) async {
    await _dio.post(
      '$serverUrl/t/$topicId/notifications',
      data: {'notification_level': notificationLevel},
      options: _authHeaders(apiKey),
    );
  }

  Future<void> bookmarkTopic(
    String serverUrl,
    String apiKey,
    int topicId,
  ) async {
    await _dio.put(
      '$serverUrl/t/$topicId/bookmark',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> unbookmarkTopic(
    String serverUrl,
    String apiKey,
    int topicId,
  ) async {
    await _dio.put(
      '$serverUrl/t/$topicId/remove_bookmarks',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> recordTimings(
    String serverUrl,
    String apiKey, {
    required int topicId,
    required Map<int, int> timings,
    required int highestSeen,
  }) async {
    final data = <String, dynamic>{
      'topic_id': topicId,
      'topic_time': timings.values.fold<int>(0, (a, b) => a + b),
      'timings': {for (final e in timings.entries) '${e.key}': e.value},
      'highest_seen': highestSeen,
    };
    await _dio.post(
      '$serverUrl/topics/timings',
      data: data,
      options: _authHeaders(apiKey),
    );
  }
}
