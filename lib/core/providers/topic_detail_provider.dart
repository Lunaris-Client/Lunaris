import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/post.dart';
import 'package:lunaris/core/models/topic_detail.dart';
import 'package:lunaris/core/providers/providers.dart';

class TopicDetailParams {
  final String serverUrl;
  final int topicId;

  const TopicDetailParams({
    required this.serverUrl,
    required this.topicId,
  });

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
    TopicDetailNotifier, TopicDetailState, TopicDetailParams>(
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

  const TopicDetailState({
    this.topic,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.loadedPostIds = const {},
  });

  TopicDetailState copyWith({
    TopicDetail? topic,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    Set<int>? loadedPostIds,
  }) {
    return TopicDetailState(
      topic: topic ?? this.topic,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      loadedPostIds: loadedPostIds ?? this.loadedPostIds,
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

  TopicDetailNotifier(this._apiClient, this._authService, this._params)
      : super(const TopicDetailState()) {
    _fetchTopic();
  }

  Future<void> _fetchTopic() async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Not authenticated',
        );
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

      final unloaded = state.topic!.postStream
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

      final newPosts = (json['post_stream']?['posts'] as List<dynamic>?)
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
}
