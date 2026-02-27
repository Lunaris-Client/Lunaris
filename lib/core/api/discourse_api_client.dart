import 'package:dio/dio.dart';
import 'package:lunaris/core/models/models.dart';

class _RateLimitInterceptor extends Interceptor {
  final Dio _retryDio;

  _RateLimitInterceptor(BaseOptions baseOptions)
      : _retryDio = Dio(baseOptions);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      final retryAfter = err.response?.headers.value('retry-after');
      final waitSeconds = int.tryParse(retryAfter ?? '') ?? 10;
      Future.delayed(Duration(seconds: waitSeconds), () async {
        try {
          final options = err.requestOptions;
          final response = await _retryDio.request(
            options.path,
            data: options.data,
            queryParameters: options.queryParameters,
            options: Options(
              method: options.method,
              headers: options.headers,
              responseType: options.responseType,
              contentType: options.contentType,
            ),
          );
          handler.resolve(response);
        } catch (e) {
          handler.reject(
            e is DioException
                ? e
                : DioException(
                    requestOptions: err.requestOptions, error: e),
          );
        }
      });
    } else {
      handler.next(err);
    }
  }
}

class DiscourseApiClient {
  late final Dio _dio;

  DiscourseApiClient({Dio? dio}) {
    final baseOptions = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Accept': 'application/json'},
    );
    _dio = dio ?? Dio(baseOptions);
    if (dio == null) {
      _dio.interceptors.add(_RateLimitInterceptor(baseOptions));
    }
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
    String? name,
    String? reminderAt,
    int? autoDeletePreference,
  }) async {
    final data = <String, dynamic>{
      'bookmarkable_id': bookmarkableId,
      'bookmarkable_type': bookmarkableType,
    };
    if (name != null) data['name'] = name;
    if (reminderAt != null) data['reminder_at'] = reminderAt;
    if (autoDeletePreference != null) {
      data['auto_delete_preference'] = autoDeletePreference;
    }
    final response = await _dio.post(
      '$serverUrl/bookmarks',
      data: data,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateBookmark(
    String serverUrl,
    String apiKey,
    int bookmarkId, {
    String? name,
    String? reminderAt,
    int? autoDeletePreference,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (reminderAt != null) data['reminder_at'] = reminderAt;
    if (autoDeletePreference != null) {
      data['auto_delete_preference'] = autoDeletePreference;
    }
    await _dio.put(
      '$serverUrl/bookmarks/$bookmarkId',
      data: data,
      options: _authHeaders(apiKey),
    );
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

  Future<Map<String, dynamic>> fetchBookmarks(
    String serverUrl,
    String apiKey, {
    required String username,
    int? page,
  }) async {
    final params = <String, dynamic>{};
    if (page != null && page > 0) params['page'] = page;
    final response = await _dio.get(
      '$serverUrl/u/$username/bookmarks.json',
      queryParameters: params.isEmpty ? null : params,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> fetchNotifications(
    String serverUrl,
    String apiKey, {
    bool recent = true,
    int? filterType,
  }) async {
    final params = <String, dynamic>{};
    if (recent) params['recent'] = true;
    if (filterType != null) params['filter_type'] = filterType;
    final response = await _dio.get(
      '$serverUrl/notifications.json',
      queryParameters: params.isEmpty ? null : params,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> markNotificationsRead(String serverUrl, String apiKey) async {
    await _dio.put(
      '$serverUrl/notifications/mark-read',
      options: _authHeaders(apiKey),
    );
  }

  Future<Map<String, dynamic>> createPost(
    String serverUrl,
    String apiKey, {
    required String raw,
    int? topicId,
    int? replyToPostNumber,
    String? title,
    int? categoryId,
    List<String>? tags,
    String? archetype,
    String? targetRecipients,
  }) async {
    final data = <String, dynamic>{'raw': raw};
    if (topicId != null) data['topic_id'] = topicId;
    if (replyToPostNumber != null) {
      data['reply_to_post_number'] = replyToPostNumber;
    }
    if (title != null) data['title'] = title;
    if (categoryId != null) data['category'] = categoryId;
    if (tags != null && tags.isNotEmpty) data['tags[]'] = tags;
    if (archetype != null) data['archetype'] = archetype;
    if (targetRecipients != null) {
      data['target_recipients'] = targetRecipients;
    }
    final response = await _dio.post(
      '$serverUrl/posts',
      data: data,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> saveDraft(
    String serverUrl,
    String apiKey, {
    required String draftKey,
    required String data,
    int draftSequence = 0,
  }) async {
    await _dio.post(
      '$serverUrl/drafts.json',
      data: {'draft_key': draftKey, 'data': data, 'sequence': draftSequence},
      options: _authHeaders(apiKey),
    );
  }

  Future<void> deleteDraft(
    String serverUrl,
    String apiKey, {
    required String draftKey,
  }) async {
    await _dio.delete(
      '$serverUrl/drafts/$draftKey.json',
      options: _authHeaders(apiKey),
    );
  }

  Future<List<dynamic>> searchTags(
    String serverUrl,
    String apiKey, {
    required String query,
  }) async {
    final response = await _dio.get(
      '$serverUrl/tags/filter/search.json',
      queryParameters: {'q': query},
      options: _authHeaders(apiKey),
    );
    return (response.data['results'] as List?) ?? [];
  }

  Future<List<dynamic>> searchSimilarTopics(
    String serverUrl,
    String apiKey, {
    required String title,
    String? raw,
  }) async {
    final response = await _dio.get(
      '$serverUrl/search/query.json',
      queryParameters: {'q': 'title:$title', if (raw != null) 'raw': raw},
      options: _authHeaders(apiKey),
    );
    final topics = response.data['topics'] as List?;
    return topics ?? [];
  }

  Future<Map<String, dynamic>> uploadFile(
    String serverUrl,
    String apiKey, {
    required String filePath,
    required String fileName,
    String type = 'composer',
  }) async {
    final formData = FormData.fromMap({
      'type': type,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post(
      '$serverUrl/uploads.json',
      data: formData,
      options: Options(
        headers: {'User-Api-Key': apiKey},
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> searchUsers(
    String serverUrl,
    String apiKey, {
    required String term,
    bool includeGroups = true,
  }) async {
    final response = await _dio.get(
      '$serverUrl/u/search/users.json',
      queryParameters: {
        'term': term,
        'include_groups': includeGroups,
      },
      options: _authHeaders(apiKey),
    );
    return (response.data['users'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> fetchPrivateMessages(
    String serverUrl,
    String apiKey, {
    required String username,
    int? page,
  }) async {
    final params = <String, dynamic>{};
    if (page != null && page > 0) params['page'] = page;
    final response = await _dio.get(
      '$serverUrl/topics/private-messages/$username.json',
      queryParameters: params.isEmpty ? null : params,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> search(
    String serverUrl,
    String apiKey, {
    required String query,
    int? page,
  }) async {
    final params = <String, dynamic>{'term': query};
    if (page != null && page > 0) params['page'] = page;
    final response = await _dio.get(
      '$serverUrl/search/query.json',
      queryParameters: params,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchUserProfile(
    String serverUrl,
    String apiKey, {
    required String username,
  }) async {
    final response = await _dio.get(
      '$serverUrl/u/$username.json',
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchUserSummary(
    String serverUrl,
    String apiKey, {
    required String username,
  }) async {
    final response = await _dio.get(
      '$serverUrl/u/$username/summary.json',
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> fetchUserBadges(
    String serverUrl,
    String apiKey, {
    required String username,
  }) async {
    final response = await _dio.get(
      '$serverUrl/u/$username/badges.json',
      options: _authHeaders(apiKey),
    );
    return (response.data['badges'] as List?) ?? [];
  }

  Future<List<dynamic>> fetchUserActions(
    String serverUrl,
    String apiKey, {
    required String username,
    int? offset,
    int? filterActionType,
  }) async {
    final params = <String, dynamic>{'username': username};
    if (offset != null) params['offset'] = offset;
    if (filterActionType != null) params['filter'] = filterActionType;
    final response = await _dio.get(
      '$serverUrl/user_actions.json',
      queryParameters: params,
      options: _authHeaders(apiKey),
    );
    return (response.data['user_actions'] as List?) ?? [];
  }

  Future<Map<String, dynamic>> fetchChatChannels(
    String serverUrl,
    String apiKey,
  ) async {
    final response = await _dio.get(
      '$serverUrl/chat/api/me/channels',
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchChatChannel(
    String serverUrl,
    String apiKey,
    int channelId,
  ) async {
    final response = await _dio.get(
      '$serverUrl/chat/api/channels/$channelId',
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchChatMessages(
    String serverUrl,
    String apiKey,
    int channelId, {
    int? pageSize,
    int? beforeMessageId,
  }) async {
    final params = <String, dynamic>{};
    if (pageSize != null) params['page_size'] = pageSize;
    if (beforeMessageId != null) params['before'] = beforeMessageId;
    final response = await _dio.get(
      '$serverUrl/chat/api/channels/$channelId/messages',
      queryParameters: params.isEmpty ? null : params,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendChatMessage(
    String serverUrl,
    String apiKey,
    int channelId, {
    required String message,
    int? inReplyToId,
  }) async {
    final data = <String, dynamic>{'message': message};
    if (inReplyToId != null) data['in_reply_to_id'] = inReplyToId;
    final response = await _dio.post(
      '$serverUrl/chat/$channelId',
      data: data,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchChatThreadMessages(
    String serverUrl,
    String apiKey,
    int channelId,
    int threadId, {
    int? pageSize,
    int? beforeMessageId,
  }) async {
    final params = <String, dynamic>{};
    if (pageSize != null) params['page_size'] = pageSize;
    if (beforeMessageId != null) params['before'] = beforeMessageId;
    final response = await _dio.get(
      '$serverUrl/chat/api/channels/$channelId/threads/$threadId/messages',
      queryParameters: params.isEmpty ? null : params,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendChatThreadMessage(
    String serverUrl,
    String apiKey,
    int channelId,
    int threadId, {
    required String message,
  }) async {
    final response = await _dio.post(
      '$serverUrl/chat/$channelId',
      data: {'message': message, 'thread_id': threadId},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> markChatChannelRead(
    String serverUrl,
    String apiKey,
    int channelId, {
    required int messageId,
  }) async {
    await _dio.put(
      '$serverUrl/chat/api/channels/$channelId/read',
      data: {'message_id': messageId},
      options: _authHeaders(apiKey),
    );
  }

  Future<void> editChatMessage(
    String serverUrl,
    String apiKey,
    int channelId,
    int messageId, {
    required String message,
  }) async {
    await _dio.put(
      '$serverUrl/chat/api/channels/$channelId/messages/$messageId',
      data: {'message': message},
      options: _authHeaders(apiKey),
    );
  }

  Future<void> deleteChatMessage(
    String serverUrl,
    String apiKey,
    int channelId,
    int messageId,
  ) async {
    await _dio.delete(
      '$serverUrl/chat/api/channels/$channelId/messages/$messageId',
      options: _authHeaders(apiKey),
    );
  }

  Future<Map<String, dynamic>> bookmarkChatMessage(
    String serverUrl,
    String apiKey, {
    required int messageId,
  }) async {
    final response = await _dio.post(
      '$serverUrl/bookmarks.json',
      data: {
        'bookmarkable_type': 'Chat::Message',
        'bookmarkable_id': messageId,
      },
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> flagChatMessage(
    String serverUrl,
    String apiKey,
    int channelId,
    int messageId, {
    required int flagType,
    String? message,
  }) async {
    final data = <String, dynamic>{'flag_type_id': flagType};
    if (message != null) data['message'] = message;
    await _dio.post(
      '$serverUrl/chat/api/channels/$channelId/messages/$messageId/flags',
      data: data,
      options: _authHeaders(apiKey),
    );
  }

  Future<void> updatePresence(
    String serverUrl,
    String apiKey, {
    required String clientId,
    List<String>? presentChannels,
    List<String>? leaveChannels,
  }) async {
    final data = <String, dynamic>{'client_id': clientId};
    if (presentChannels != null) data['present_channels'] = presentChannels;
    if (leaveChannels != null) data['leave_channels'] = leaveChannels;
    await _dio.post(
      '$serverUrl/presence/update',
      data: data,
      options: _authHeaders(apiKey),
    );
  }

  Future<void> reactChatMessage(
    String serverUrl,
    String apiKey,
    int channelId,
    int messageId, {
    required String emoji,
    required String action,
  }) async {
    await _dio.put(
      '$serverUrl/chat/$channelId/react/$messageId',
      data: {'emoji': emoji, 'react_action': action},
      options: _authHeaders(apiKey),
    );
  }

  Future<Map<String, dynamic>> createDirectMessageChannel(
    String serverUrl,
    String apiKey, {
    required List<String> targetUsernames,
    String? name,
  }) async {
    final data = <String, dynamic>{
      'target_usernames': targetUsernames.join(','),
    };
    if (name != null && name.isNotEmpty) data['name'] = name;
    final response = await _dio.post(
      '$serverUrl/chat/api/direct-message-channels',
      data: data,
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPresence(
    String serverUrl,
    String apiKey, {
    required List<String> channels,
  }) async {
    final response = await _dio.get(
      '$serverUrl/presence/get',
      queryParameters: {'channels[]': channels},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> setTopicStatus(
    String serverUrl,
    String apiKey,
    int topicId, {
    required String status,
    required bool enabled,
    String? until,
  }) async {
    await _dio.put(
      '$serverUrl/t/$topicId/status',
      data: {
        'status': status,
        'enabled': enabled.toString(),
        if (until != null) 'until': until,
      },
      options: _authHeaders(apiKey),
    );
  }

  Future<void> deletePost(
    String serverUrl,
    String apiKey,
    int postId, {
    bool forceDestroy = false,
  }) async {
    await _dio.delete(
      '$serverUrl/posts/$postId',
      queryParameters: {if (forceDestroy) 'force_destroy': true},
      options: _authHeaders(apiKey),
    );
  }

  Future<void> recoverPost(
    String serverUrl,
    String apiKey,
    int postId,
  ) async {
    await _dio.put(
      '$serverUrl/posts/$postId/recover',
      options: _authHeaders(apiKey),
    );
  }

  Future<Map<String, dynamic>> editPost(
    String serverUrl,
    String apiKey,
    int postId, {
    required String raw,
    String? editReason,
  }) async {
    final response = await _dio.put(
      '$serverUrl/posts/$postId',
      data: {
        'post': {
          'raw': raw,
          if (editReason != null) 'edit_reason': editReason,
        },
      },
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchReviewQueue(
    String serverUrl,
    String apiKey, {
    String status = 'pending',
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '$serverUrl/review.json',
      queryParameters: {'status': status, 'offset': offset},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> performReviewAction(
    String serverUrl,
    String apiKey,
    int reviewableId, {
    required String actionId,
    required int version,
  }) async {
    final response = await _dio.put(
      '$serverUrl/review/$reviewableId/perform/$actionId',
      data: {'version': version},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> suspendUser(
    String serverUrl,
    String apiKey,
    int userId, {
    required String reason,
    required String suspendUntil,
    String? message,
  }) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/suspend',
      data: {
        'reason': reason,
        'suspend_until': suspendUntil,
        if (message != null) 'message': message,
      },
      options: _authHeaders(apiKey),
    );
  }

  Future<void> silenceUser(
    String serverUrl,
    String apiKey,
    int userId, {
    required String reason,
    required String silencedTill,
    String? message,
  }) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/silence',
      data: {
        'reason': reason,
        'silenced_till': silencedTill,
        if (message != null) 'message': message,
      },
      options: _authHeaders(apiKey),
    );
  }

  Future<Map<String, dynamic>> fetchAdminUser(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    final response = await _dio.get(
      '$serverUrl/admin/users/$userId.json',
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> unsuspendUser(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/unsuspend',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> unsilenceUser(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/unsilence',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> grantAdmin(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/grant_admin',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> revokeAdmin(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/revoke_admin',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> grantModeration(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/grant_moderation',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> revokeModeration(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/revoke_moderation',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> logOutUser(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.post(
      '$serverUrl/admin/users/$userId/log_out',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> activateUser(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/activate',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> deactivateUser(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/deactivate',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> changeTrustLevel(
    String serverUrl,
    String apiKey,
    int userId,
    int level,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/trust_level',
      data: {'level': level},
      options: _authHeaders(apiKey),
    );
  }

  Future<void> deleteUser(
    String serverUrl,
    String apiKey,
    int userId, {
    bool deletePosts = false,
    bool blockEmail = false,
    bool blockIp = false,
    bool blockUrls = false,
  }) async {
    await _dio.delete(
      '$serverUrl/admin/users/$userId.json',
      data: {
        'delete_posts': deletePosts,
        'block_email': blockEmail,
        'block_ip': blockIp,
        'block_urls': blockUrls,
      },
      options: _authHeaders(apiKey),
    );
  }

  Future<void> anonymizeUser(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/anonymize',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> disableSecondFactor(
    String serverUrl,
    String apiKey,
    int userId,
  ) async {
    await _dio.put(
      '$serverUrl/admin/users/$userId/disable_second_factor',
      options: _authHeaders(apiKey),
    );
  }

  Future<void> flagPost(
    String serverUrl,
    String apiKey,
    int postId, {
    required int flagTypeId,
    String? message,
  }) async {
    await _dio.post(
      '$serverUrl/post_actions',
      data: {
        'id': postId,
        'post_action_type_id': flagTypeId,
        if (message != null) 'message': message,
      },
      options: _authHeaders(apiKey),
    );
  }

  Future<Map<String, dynamic>> acceptAnswer(
    String serverUrl,
    String apiKey,
    int postId,
  ) async {
    final response = await _dio.post(
      '$serverUrl/solution/accept',
      data: {'id': postId},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unacceptAnswer(
    String serverUrl,
    String apiKey,
    int postId,
  ) async {
    final response = await _dio.post(
      '$serverUrl/solution/unaccept',
      data: {'id': postId},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> voteOnTopic(
    String serverUrl,
    String apiKey,
    int topicId,
  ) async {
    final response = await _dio.post(
      '$serverUrl/voting/vote',
      data: {'topic_id': topicId},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unvoteTopic(
    String serverUrl,
    String apiKey,
    int topicId,
  ) async {
    final response = await _dio.post(
      '$serverUrl/voting/unvote',
      data: {'topic_id': topicId},
      options: _authHeaders(apiKey),
    );
    return response.data as Map<String, dynamic>;
  }
}
