import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/storage/offline_action_queue.dart';
import 'package:uuid/uuid.dart';

final offlineActionQueueProvider = Provider<OfflineActionQueue>((ref) {
  return OfflineActionQueue(ref.watch(sharedPreferencesProvider));
});

final offlineActionServiceProvider = Provider<OfflineActionService>((ref) {
  return OfflineActionService(
    queue: ref.watch(offlineActionQueueProvider),
    apiClient: ref.watch(discourseApiClientProvider),
    authService: ref.watch(authServiceProvider),
  );
});

final pendingActionCountProvider = Provider<int>((ref) {
  return ref.watch(offlineActionQueueProvider).pendingCount;
});

class OfflineActionService {
  final OfflineActionQueue _queue;
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  static const _uuid = Uuid();

  OfflineActionService({
    required OfflineActionQueue queue,
    required DiscourseApiClient apiClient,
    required AuthService authService,
  })  : _queue = queue,
        _apiClient = apiClient,
        _authService = authService;

  Future<void> enqueueLike(String serverUrl, int postId) async {
    await _queue.enqueue(OfflineAction(
      id: _uuid.v4(),
      serverUrl: serverUrl,
      type: 'like',
      payload: {'postId': postId},
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueBookmark(
    String serverUrl,
    int bookmarkableId, {
    String bookmarkableType = 'Post',
  }) async {
    await _queue.enqueue(OfflineAction(
      id: _uuid.v4(),
      serverUrl: serverUrl,
      type: 'bookmark',
      payload: {
        'bookmarkableId': bookmarkableId,
        'bookmarkableType': bookmarkableType,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueuePost(
    String serverUrl, {
    required int topicId,
    required String raw,
    int? replyToPostNumber,
  }) async {
    await _queue.enqueue(OfflineAction(
      id: _uuid.v4(),
      serverUrl: serverUrl,
      type: 'post',
      payload: {
        'topicId': topicId,
        'raw': raw,
        if (replyToPostNumber != null) 'replyToPostNumber': replyToPostNumber,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<int> replayAll() async {
    final actions = _queue.getAll();
    int replayed = 0;

    for (final action in actions) {
      try {
        final apiKey = await _authService.loadApiKey(action.serverUrl);
        if (apiKey == null) continue;

        switch (action.type) {
          case 'like':
            await _apiClient.createPostAction(
              action.serverUrl,
              apiKey,
              postId: action.payload['postId'] as int,
              postActionTypeId: 2,
            );
          case 'bookmark':
            await _apiClient.createBookmark(
              action.serverUrl,
              apiKey,
              bookmarkableId: action.payload['bookmarkableId'] as int,
              bookmarkableType:
                  action.payload['bookmarkableType'] as String? ?? 'Post',
            );
          case 'post':
            await _apiClient.createPost(
              action.serverUrl,
              apiKey,
              topicId: action.payload['topicId'] as int,
              raw: action.payload['raw'] as String,
              replyToPostNumber: action.payload['replyToPostNumber'] as int?,
            );
        }

        await _queue.remove(action.id);
        replayed++;
      } catch (_) {}
    }

    return replayed;
  }
}
