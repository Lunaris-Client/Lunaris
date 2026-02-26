import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/post.dart';
import 'package:lunaris/core/models/topic_detail.dart';
import 'package:lunaris/core/providers/providers.dart';

class TopicDetailParams {
  final String serverUrl;
  final int topicId;

  const TopicDetailParams({required this.serverUrl, required this.topicId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicDetailParams &&
          serverUrl == other.serverUrl &&
          topicId == other.topicId;

  @override
  int get hashCode => Object.hash(serverUrl, topicId);
}

final topicDetailProvider = StateNotifierProvider.family<
  TopicDetailNotifier,
  TopicDetailState,
  TopicDetailParams
>(
  (ref, params) => TopicDetailNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class TopicDetailState {
  final TopicDetail? topic;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Set<int> loadedPostIds;
  final int currentPostIndex;

  const TopicDetailState({
    this.topic,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadedPostIds = const {},
    this.currentPostIndex = 0,
  });

  TopicDetailState copyWith({
    TopicDetail? topic,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    Set<int>? loadedPostIds,
    int? currentPostIndex,
  }) {
    return TopicDetailState(
      topic: topic ?? this.topic,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      loadedPostIds: loadedPostIds ?? this.loadedPostIds,
      currentPostIndex: currentPostIndex ?? this.currentPostIndex,
    );
  }

  bool get hasMorePosts {
    if (topic == null) return false;
    return loadedPostIds.length < topic!.postStream.length;
  }
}

class TopicDetailNotifier extends StateNotifier<TopicDetailState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final TopicDetailParams _params;
  static const _chunkSize = 20;
  static const _timingsInterval = Duration(seconds: 5);

  Timer? _timingsTimer;
  final Map<int, int> _pendingTimings = {};
  int _highestSeen = 0;

  TopicDetailNotifier(this._apiClient, this._authService, this._params)
    : super(const TopicDetailState()) {
    _fetchTopic();
    _timingsTimer = Timer.periodic(_timingsInterval, (_) => _flushTimings());
  }

  @override
  void dispose() {
    _flushTimings();
    _timingsTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTopic() async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated');
        return;
      }

      final json = await _apiClient.fetchTopicDetail(
        _params.serverUrl,
        apiKey,
        _params.topicId,
      );

      final detail = TopicDetail.fromApiJson(json);
      final loaded = detail.posts.map((p) => p.id).toSet();

      state = state.copyWith(
        topic: detail,
        isLoading: false,
        loadedPostIds: loaded,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMorePosts() async {
    if (state.isLoadingMore || !state.hasMorePosts || state.topic == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);

    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final unloaded =
          state.topic!.postStream
              .where((id) => !state.loadedPostIds.contains(id))
              .take(_chunkSize)
              .toList();

      if (unloaded.isEmpty) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }

      final json = await _apiClient.fetchTopicPosts(
        _params.serverUrl,
        apiKey,
        _params.topicId,
        unloaded,
      );

      final newPosts =
          (json['post_stream']?['posts'] as List<dynamic>?)
              ?.map((p) => Post.fromApiJson(p as Map<String, dynamic>))
              .toList() ??
          [];

      final updatedLoaded = {...state.loadedPostIds};
      for (final p in newPosts) {
        updatedLoaded.add(p.id);
      }

      final allPosts = [...state.topic!.posts, ...newPosts];
      allPosts.sort((a, b) => a.postNumber.compareTo(b.postNumber));

      state = state.copyWith(
        topic: state.topic!.copyWith(posts: allPosts),
        isLoadingMore: false,
        loadedPostIds: updatedLoaded,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Future<void> refresh() async {
    state = const TopicDetailState();
    await _fetchTopic();
  }

  Future<String?> _getApiKey() => _authService.loadApiKey(_params.serverUrl);

  Post? _findPost(int postId) =>
      state.topic?.posts.where((p) => p.id == postId).firstOrNull;

  void _updatePost(int postId, Post Function(Post) transform) {
    if (state.topic == null) return;
    final updated =
        state.topic!.posts.map((p) {
          return p.id == postId ? transform(p) : p;
        }).toList();
    state = state.copyWith(topic: state.topic!.copyWith(posts: updated));
  }

  Future<void> toggleLike(int postId) async {
    final post = _findPost(postId);
    if (post == null) return;

    final likeAction = post.actionsSummary.where((a) => a.id == 2).firstOrNull;
    if (likeAction == null) return;

    final wasLiked = likeAction.acted;

    _updatePost(postId, (p) {
      final newActions =
          p.actionsSummary.map((a) {
            if (a.id != 2) return a;
            return a.copyWith(
              acted: !wasLiked,
              count: wasLiked ? a.count - 1 : a.count + 1,
              canUndo: !wasLiked,
            );
          }).toList();
      return p.copyWith(
        actionsSummary: newActions,
        likeCount: wasLiked ? p.likeCount - 1 : p.likeCount + 1,
      );
    });

    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) return;

      if (wasLiked) {
        await _apiClient.deletePostAction(
          _params.serverUrl,
          apiKey,
          postId: postId,
          postActionTypeId: 2,
        );
      } else {
        await _apiClient.createPostAction(
          _params.serverUrl,
          apiKey,
          postId: postId,
          postActionTypeId: 2,
        );
      }
    } catch (_) {
      _updatePost(postId, (p) {
        final reverted =
            p.actionsSummary.map((a) {
              if (a.id != 2) return a;
              return a.copyWith(
                acted: wasLiked,
                count: wasLiked ? a.count + 1 : a.count - 1,
                canUndo: wasLiked,
              );
            }).toList();
        return p.copyWith(
          actionsSummary: reverted,
          likeCount: wasLiked ? p.likeCount + 1 : p.likeCount - 1,
        );
      });
    }
  }

  Future<void> toggleBookmark(int postId) async {
    final post = _findPost(postId);
    if (post == null) return;

    final wasBookmarked = post.bookmarked;

    _updatePost(postId, (p) => p.copyWith(bookmarked: !wasBookmarked));

    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) return;

      if (wasBookmarked) {
        final bmId = post.bookmarkId;
        if (bmId == null) return;
        await _apiClient.deleteBookmark(_params.serverUrl, apiKey, bmId);
        _updatePost(postId, (p) => p.copyWith(bookmarkId: null));
      } else {
        final result = await _apiClient.createBookmark(
          _params.serverUrl,
          apiKey,
          bookmarkableId: postId,
        );
        final newId = result['id'] as int?;
        _updatePost(postId, (p) => p.copyWith(bookmarkId: newId));
      }
    } catch (_) {
      _updatePost(
        postId,
        (p) =>
            p.copyWith(bookmarked: wasBookmarked, bookmarkId: post.bookmarkId),
      );
    }
  }

  Future<void> toggleTopicBookmark() async {
    if (state.topic == null) return;

    final wasBookmarked = state.topic!.bookmarked;
    state = state.copyWith(
      topic: state.topic!.copyWith(bookmarked: !wasBookmarked),
    );

    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) return;

      if (wasBookmarked) {
        await _apiClient.unbookmarkTopic(
          _params.serverUrl,
          apiKey,
          _params.topicId,
        );
      } else {
        await _apiClient.bookmarkTopic(
          _params.serverUrl,
          apiKey,
          _params.topicId,
        );
      }
    } catch (_) {
      state = state.copyWith(
        topic: state.topic!.copyWith(bookmarked: wasBookmarked),
      );
    }
  }

  Future<void> setNotificationLevel(int level) async {
    if (state.topic == null) return;

    final previous = state.topic!.notificationLevel;
    state = state.copyWith(
      topic: state.topic!.copyWith(notificationLevel: level),
    );

    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) return;

      await _apiClient.setTopicNotificationLevel(
        _params.serverUrl,
        apiKey,
        _params.topicId,
        level,
      );
    } catch (_) {
      state = state.copyWith(
        topic: state.topic!.copyWith(notificationLevel: previous),
      );
    }
  }

  void updateCurrentPostIndex(int index) {
    if (index == state.currentPostIndex) return;
    state = state.copyWith(currentPostIndex: index);

    if (state.topic == null) return;
    final posts = state.topic!.posts;
    if (index < 0 || index >= posts.length) return;

    final postNumber = posts[index].postNumber;
    _pendingTimings[postNumber] =
        (_pendingTimings[postNumber] ?? 0) + _timingsInterval.inMilliseconds;
    if (postNumber > _highestSeen) _highestSeen = postNumber;
  }

  Future<void> _flushTimings() async {
    if (_pendingTimings.isEmpty || state.topic == null) return;

    final batch = Map<int, int>.of(_pendingTimings);
    final highest = _highestSeen;
    _pendingTimings.clear();

    try {
      final apiKey = await _getApiKey();
      if (apiKey == null) return;

      await _apiClient.recordTimings(
        _params.serverUrl,
        apiKey,
        topicId: _params.topicId,
        timings: batch,
        highestSeen: highest,
      );

      if (state.topic != null) {
        final lastRead = state.topic!.lastReadPostNumber ?? 0;
        if (highest > lastRead) {
          state = state.copyWith(
            topic: state.topic!.copyWith(lastReadPostNumber: highest),
          );
        }
      }
    } catch (_) {
      _pendingTimings.addAll(batch);
    }
  }

  int? get firstUnreadPostNumber {
    if (state.topic == null) return null;
    final lastRead = state.topic!.lastReadPostNumber ?? 0;
    if (lastRead >= state.topic!.highestPostNumber) return null;
    return lastRead + 1;
  }
}
