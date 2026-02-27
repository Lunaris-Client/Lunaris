import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/reviewable.dart';
import 'package:lunaris/core/providers/providers.dart';

class ReviewQueueState {
  final List<Reviewable> items;
  final bool isLoading;
  final bool hasMore;
  final int totalCount;
  final Object? error;
  final String statusFilter;

  const ReviewQueueState({
    this.items = const [],
    this.isLoading = true,
    this.hasMore = true,
    this.totalCount = 0,
    this.error,
    this.statusFilter = 'pending',
  });

  ReviewQueueState copyWith({
    List<Reviewable>? items,
    bool? isLoading,
    bool? hasMore,
    int? totalCount,
    Object? error,
    bool clearError = false,
    String? statusFilter,
  }) {
    return ReviewQueueState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      totalCount: totalCount ?? this.totalCount,
      error: clearError ? null : (error ?? this.error),
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class ReviewQueueParams {
  final String serverUrl;

  const ReviewQueueParams({required this.serverUrl});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewQueueParams && serverUrl == other.serverUrl;

  @override
  int get hashCode => serverUrl.hashCode;
}

final reviewQueueProvider = StateNotifierProvider.family<
    ReviewQueueNotifier, ReviewQueueState, ReviewQueueParams>(
  (ref, params) => ReviewQueueNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    params,
  ),
);

class ReviewQueueNotifier extends StateNotifier<ReviewQueueState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final ReviewQueueParams _params;

  ReviewQueueNotifier(this._apiClient, this._authService, this._params)
      : super(const ReviewQueueState()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      final data = await _apiClient.fetchReviewQueue(
        _params.serverUrl,
        apiKey,
        status: state.statusFilter,
      );

      final usersById = _parseUsers(data['users'] as List<dynamic>? ?? []);
      final reviewablesJson = data['reviewables'] as List<dynamic>? ?? [];
      final items = reviewablesJson
          .map((r) =>
              Reviewable.fromJson(r as Map<String, dynamic>, usersById))
          .toList();

      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      final total = meta['total_rows_reviewables'] as int? ?? items.length;

      if (!mounted) return;
      state = state.copyWith(
        items: items,
        isLoading: false,
        totalCount: total,
        hasMore: items.length < total,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e, isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    try {
      state = state.copyWith(isLoading: true);
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      final data = await _apiClient.fetchReviewQueue(
        _params.serverUrl,
        apiKey,
        status: state.statusFilter,
        offset: state.items.length,
      );

      final usersById = _parseUsers(data['users'] as List<dynamic>? ?? []);
      final reviewablesJson = data['reviewables'] as List<dynamic>? ?? [];
      final newItems = reviewablesJson
          .map((r) =>
              Reviewable.fromJson(r as Map<String, dynamic>, usersById))
          .toList();

      final meta = data['meta'] as Map<String, dynamic>? ?? {};
      final total = meta['total_rows_reviewables'] as int? ?? 0;

      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...newItems],
        isLoading: false,
        totalCount: total,
        hasMore: state.items.length + newItems.length < total,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> performAction(int reviewableId, String actionId, int version) async {
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return false;

      await _apiClient.performReviewAction(
        _params.serverUrl,
        apiKey,
        reviewableId,
        actionId: actionId,
        version: version,
      );

      if (!mounted) return true;
      state = state.copyWith(
        items: state.items.where((r) => r.id != reviewableId).toList(),
        totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(error: e);
      return false;
    }
  }

  void setFilter(String status) {
    if (status == state.statusFilter) return;
    state = ReviewQueueState(statusFilter: status);
    fetch();
  }

  Future<void> refresh() async {
    state = ReviewQueueState(statusFilter: state.statusFilter);
    await fetch();
  }

  Map<int, ReviewableUser> _parseUsers(List<dynamic> usersJson) {
    final map = <int, ReviewableUser>{};
    for (final u in usersJson) {
      final user = ReviewableUser.fromJson(u as Map<String, dynamic>);
      map[user.id] = user;
    }
    return map;
  }
}
