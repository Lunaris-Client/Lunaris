import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/providers/providers.dart';

class BadgeCounts {
  final int unreadPersonalMessages;
  final int newTopics;
  final int unreadTopics;
  final bool isLoading;
  final Object? error;

  const BadgeCounts({
    this.unreadPersonalMessages = 0,
    this.newTopics = 0,
    this.unreadTopics = 0,
    this.isLoading = true,
    this.error,
  });

  int get feedBadgeCount => newTopics + unreadTopics;

  BadgeCounts copyWith({
    int? unreadPersonalMessages,
    int? newTopics,
    int? unreadTopics,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) {
    return BadgeCounts(
      unreadPersonalMessages:
          unreadPersonalMessages ?? this.unreadPersonalMessages,
      newTopics: newTopics ?? this.newTopics,
      unreadTopics: unreadTopics ?? this.unreadTopics,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final badgeCountsProvider =
    StateNotifierProvider.family<BadgeCountsNotifier, BadgeCounts, String>(
  (ref, serverUrl) => BadgeCountsNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    serverUrl,
  ),
);

class BadgeCountsNotifier extends StateNotifier<BadgeCounts> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final String _serverUrl;

  BadgeCountsNotifier(this._apiClient, this._authService, this._serverUrl)
      : super(const BadgeCounts()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      final apiKey = await _authService.loadApiKey(_serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated');
        return;
      }

      final json =
          await _apiClient.fetchNotificationTotals(_serverUrl, apiKey);

      final tracking = json['topic_tracking'] as Map<String, dynamic>? ?? {};

      state = BadgeCounts(
        unreadPersonalMessages:
            json['unread_personal_messages'] as int? ?? 0,
        newTopics: tracking['new'] as int? ?? 0,
        unreadTopics: tracking['unread'] as int? ?? 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

}
