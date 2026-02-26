import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/providers/providers.dart';

class PmListParams {
  final String serverUrl;
  final String username;

  const PmListParams({required this.serverUrl, required this.username});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PmListParams &&
          serverUrl == other.serverUrl &&
          username == other.username;

  @override
  int get hashCode => Object.hash(serverUrl, username);
}

final pmListProvider =
    StateNotifierProvider.family<PmListNotifier, PmListState, PmListParams>(
  (ref, params) => PmListNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class PmListState {
  final List<Topic> topics;
  final Map<int, TopicUser> users;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final Object? error;

  const PmListState({
    this.topics = const [],
    this.users = const {},
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  PmListState copyWith({
    List<Topic>? topics,
    Map<int, TopicUser>? users,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    Object? error,
    bool clearError = false,
  }) {
    return PmListState(
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

class PmListNotifier extends StateNotifier<PmListState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final PmListParams _params;

  PmListNotifier(this._apiClient, this._authService, this._params)
      : super(const PmListState()) {
    _fetchFirstPage();
  }

  Future<void> refresh() => _fetchFirstPage();

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) throw StateError('No API key');

      final nextPage = state.currentPage + 1;
      final raw = await _apiClient.fetchPrivateMessages(
        _params.serverUrl,
        apiKey,
        username: _params.username,
        page: nextPage,
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

  Future<void> _fetchFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) throw StateError('No API key');

      final raw = await _apiClient.fetchPrivateMessages(
        _params.serverUrl,
        apiKey,
        username: _params.username,
      );
      final response = TopicListResponse.fromApiJson(raw);

      state = PmListState(
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
