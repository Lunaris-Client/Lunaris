import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/providers/providers.dart';

class CategoryUnreadCounts {
  final Map<int, int> newPerCategory;
  final Map<int, int> unreadPerCategory;
  final bool isLoading;
  final Object? error;

  const CategoryUnreadCounts({
    this.newPerCategory = const {},
    this.unreadPerCategory = const {},
    this.isLoading = true,
    this.error,
  });

  int totalForCategory(int categoryId) =>
      (newPerCategory[categoryId] ?? 0) +
      (unreadPerCategory[categoryId] ?? 0);

  CategoryUnreadCounts copyWith({
    Map<int, int>? newPerCategory,
    Map<int, int>? unreadPerCategory,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return CategoryUnreadCounts(
      newPerCategory: newPerCategory ?? this.newPerCategory,
      unreadPerCategory: unreadPerCategory ?? this.unreadPerCategory,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final categoryUnreadProvider = StateNotifierProvider.family<
    CategoryUnreadNotifier, CategoryUnreadCounts, String>(
  (ref, serverUrl) => CategoryUnreadNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    serverUrl,
  ),
);

class CategoryUnreadNotifier extends StateNotifier<CategoryUnreadCounts> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final String _serverUrl;
  DateTime _lastFetchTime = DateTime(2000);
  static const _cooldown = Duration(seconds: 10);

  CategoryUnreadNotifier(this._apiClient, this._authService, this._serverUrl)
      : super(const CategoryUnreadCounts()) {
    fetch();
  }

  Future<void> fetch({bool force = false}) async {
    final now = DateTime.now();
    if (!force && now.difference(_lastFetchTime) < _cooldown) return;
    _lastFetchTime = now;

    try {
      final apiKey = await _authService.loadApiKey(_serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated');
        return;
      }

      final results = await Future.wait([
        _apiClient.fetchTopicList(_serverUrl, apiKey, filter: 'new'),
        _apiClient.fetchTopicList(_serverUrl, apiKey, filter: 'unread'),
      ]);

      if (!mounted) return;

      final newCounts = _countByCategory(results[0]);
      final unreadCounts = _countByCategory(results[1]);

      state = CategoryUnreadCounts(
        newPerCategory: newCounts,
        unreadPerCategory: unreadCounts,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[CategoryUnread] fetch error: $e');
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e);
      }
    }
  }

  Map<int, int> _countByCategory(Map<String, dynamic> response) {
    final topicList =
        response['topic_list'] as Map<String, dynamic>? ?? {};
    final topics = topicList['topics'] as List<dynamic>? ?? [];
    final counts = <int, int>{};
    for (final t in topics) {
      if (t is Map<String, dynamic>) {
        final catId = t['category_id'] as int?;
        if (catId != null) {
          counts[catId] = (counts[catId] ?? 0) + 1;
        }
      }
    }
    return counts;
  }
}
