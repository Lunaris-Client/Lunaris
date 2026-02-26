import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/search_result.dart';
import 'package:lunaris/core/providers/providers.dart';

class SearchState {
  final SearchResult? result;
  final bool isLoading;
  final Object? error;
  final String query;

  const SearchState({
    this.result,
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SearchState copyWith({
    SearchResult? result,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    String? query,
  }) {
    return SearchState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
    );
  }
}

final searchProvider =
    StateNotifierProvider.family<SearchNotifier, SearchState, String>(
  (ref, serverUrl) => SearchNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    serverUrl,
  ),
);

class SearchNotifier extends StateNotifier<SearchState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final String _serverUrl;
  Timer? _debounce;

  SearchNotifier(this._apiClient, this._authService, this._serverUrl)
      : super(const SearchState());

  void search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = const SearchState();
      return;
    }
    state = state.copyWith(query: query, isLoading: true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _execute(query));
  }

  Future<void> _execute(String query) async {
    try {
      final apiKey = await _authService.loadApiKey(_serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated');
        return;
      }

      final json = await _apiClient.search(
        _serverUrl,
        apiKey,
        query: query,
      );

      final result = SearchResult.fromApiJson(json);
      final topicMap = {for (final t in result.topics) t.id: t};
      final postsWithTitles = result.posts.map((p) {
        final topic = topicMap[p.topicId];
        if (topic != null && p.topicTitle == null) {
          return SearchPost(
            id: p.id,
            username: p.username,
            avatarTemplate: p.avatarTemplate,
            blurb: p.blurb,
            topicId: p.topicId,
            topicTitle: topic.title,
            postNumber: p.postNumber,
            likeCount: p.likeCount,
            createdAt: p.createdAt,
          );
        }
        return p;
      }).toList();

      state = state.copyWith(
        result: SearchResult(
          posts: postsWithTitles,
          topics: result.topics,
          users: result.users,
          categories: result.categories,
          tags: result.tags,
        ),
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  void clear() {
    _debounce?.cancel();
    state = const SearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
