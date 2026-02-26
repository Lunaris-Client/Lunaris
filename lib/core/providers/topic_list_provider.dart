import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/providers/providers.dart';

class TopicListParams {
  final String serverUrl;
  final String filter;
  final int? categoryId;
  final String? categorySlug;
  final String? tagName;
  final String? period;

  const TopicListParams({
    required this.serverUrl,
    this.filter = 'latest',
    this.categoryId,
    this.categorySlug,
    this.tagName,
    this.period,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicListParams &&
          serverUrl == other.serverUrl &&
          filter == other.filter &&
          categoryId == other.categoryId &&
          tagName == other.tagName &&
          period == other.period;

  @override
  int get hashCode => Object.hash(serverUrl, filter, categoryId, tagName, period);
}

final topicListProvider = StateNotifierProvider.family<
    TopicListNotifier, TopicListState, TopicListParams>(
  (ref, params) => TopicListNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class TopicListState {
  final List<Topic> topics;
  final Map<int, TopicUser> users;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final Object? error;

  const TopicListState({
    this.topics = const [],
    this.users = const {},
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  TopicListState copyWith({
    List<Topic>? topics,
    Map<int, TopicUser>? users,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    Object? error,
    bool clearError = false,
  }) {
    return TopicListState(
      topics: topics ?? this.topics,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TopicListNotifier extends StateNotifier<TopicListState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final TopicListParams _params;

  TopicListNotifier(this._apiClient, this._authService, this._params)
      : super(const TopicListState()) {
    loadInitial();
  }

  Future<void> loadInitial() => _fetchFirstPage();

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) throw StateError('No API key');

      final nextPage = state.currentPage + 1;
      final raw = await _apiClient.fetchTopicList(
        _params.serverUrl,
        apiKey,
        filter: _params.filter,
        page: nextPage,
        categoryId: _params.categoryId,
        categorySlug: _params.categorySlug,
        tagName: _params.tagName,
        period: _params.period,
      );
      final response = TopicListResponse.fromApiJson(raw);

      final mergedUsers = Map<int, TopicUser>.from(state.users)
        ..addAll(response.users);

      state = state.copyWith(
        topics: [...state.topics, ...response.topics],
        users: mergedUsers,
        isLoadingMore: false,
        hasMore: response.moreTopicsUrl != null,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Future<void> refresh() => _fetchFirstPage();

  Future<void> _fetchFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) throw StateError('No API key');

      final raw = await _apiClient.fetchTopicList(
        _params.serverUrl,
        apiKey,
        filter: _params.filter,
        categoryId: _params.categoryId,
        categorySlug: _params.categorySlug,
        tagName: _params.tagName,
        period: _params.period,
      );
      final response = TopicListResponse.fromApiJson(raw);

      state = TopicListState(
        topics: response.topics,
        users: response.users,
        isLoading: false,
        hasMore: response.moreTopicsUrl != null,
        currentPage: 0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}
