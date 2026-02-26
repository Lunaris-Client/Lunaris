import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/bookmark.dart';
import 'package:lunaris/core/providers/providers.dart';

class BookmarkListParams {
  final String serverUrl;
  final String username;

  const BookmarkListParams({
    required this.serverUrl,
    required this.username,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookmarkListParams &&
          serverUrl == other.serverUrl &&
          username == other.username;

  @override
  int get hashCode => Object.hash(serverUrl, username);
}

final bookmarkListProvider = StateNotifierProvider.family<
    BookmarkListNotifier, BookmarkListState, BookmarkListParams>(
  (ref, params) => BookmarkListNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class BookmarkListState {
  final List<Bookmark> bookmarks;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final Object? error;

  const BookmarkListState({
    this.bookmarks = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.error,
  });

  BookmarkListState copyWith({
    List<Bookmark>? bookmarks,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    Object? error,
    bool clearError = false,
  }) {
    return BookmarkListState(
      bookmarks: bookmarks ?? this.bookmarks,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BookmarkListNotifier extends StateNotifier<BookmarkListState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final BookmarkListParams _params;

  BookmarkListNotifier(this._apiClient, this._authService, this._params)
      : super(const BookmarkListState()) {
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
      final raw = await _apiClient.fetchBookmarks(
        _params.serverUrl,
        apiKey,
        username: _params.username,
        page: nextPage,
      );
      final parsed = _parseResponse(raw);

      state = state.copyWith(
        bookmarks: [...state.bookmarks, ...parsed.bookmarks],
        isLoadingMore: false,
        hasMore: parsed.hasMore,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    final original = List<Bookmark>.from(state.bookmarks);
    state = state.copyWith(
      bookmarks: state.bookmarks.where((b) => b.id != bookmarkId).toList(),
    );

    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;
      await _apiClient.deleteBookmark(_params.serverUrl, apiKey, bookmarkId);
    } catch (_) {
      state = state.copyWith(bookmarks: original);
    }
  }

  Future<void> _fetchFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) throw StateError('No API key');

      final raw = await _apiClient.fetchBookmarks(
        _params.serverUrl,
        apiKey,
        username: _params.username,
      );
      final parsed = _parseResponse(raw);

      state = BookmarkListState(
        bookmarks: parsed.bookmarks,
        isLoading: false,
        hasMore: parsed.hasMore,
        currentPage: 0,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  _BookmarkPage _parseResponse(Map<String, dynamic> raw) {
    if (raw.containsKey('bookmarks') &&
        !raw.containsKey('user_bookmark_list')) {
      return const _BookmarkPage(bookmarks: [], hasMore: false);
    }

    final list = raw['user_bookmark_list'] as Map<String, dynamic>? ?? raw;
    final items = (list['bookmarks'] as List?)
            ?.map((b) => Bookmark.fromApiJson(b as Map<String, dynamic>))
            .toList() ??
        [];
    final moreUrl = list['more_bookmarks_url'] as String?;

    return _BookmarkPage(bookmarks: items, hasMore: moreUrl != null);
  }
}

class _BookmarkPage {
  final List<Bookmark> bookmarks;
  final bool hasMore;
  const _BookmarkPage({required this.bookmarks, required this.hasMore});
}
