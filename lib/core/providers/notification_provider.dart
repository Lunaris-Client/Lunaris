import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/discourse_notification.dart';
import 'package:lunaris/core/providers/providers.dart';

enum NotificationFilter { all, replies, mentions, likes, messages, other }

class NotificationListState {
  final List<DiscourseNotification> notifications;
  final bool isLoading;
  final bool isMarkingRead;
  final Object? error;
  final NotificationFilter activeFilter;

  const NotificationListState({
    this.notifications = const [],
    this.isLoading = true,
    this.isMarkingRead = false,
    this.error,
    this.activeFilter = NotificationFilter.all,
  });

  NotificationListState copyWith({
    List<DiscourseNotification>? notifications,
    bool? isLoading,
    bool? isMarkingRead,
    Object? error,
    bool clearError = false,
    NotificationFilter? activeFilter,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      isMarkingRead: isMarkingRead ?? this.isMarkingRead,
      error: clearError ? null : (error ?? this.error),
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }

  int get unreadCount => notifications.where((n) => !n.read).length;

  List<DiscourseNotification> get filtered {
    if (activeFilter == NotificationFilter.all) return notifications;
    return notifications.where((n) => _matchesFilter(n, activeFilter)).toList();
  }

  static bool _matchesFilter(
    DiscourseNotification n,
    NotificationFilter filter,
  ) {
    return switch (filter) {
      NotificationFilter.all => true,
      NotificationFilter.replies =>
        n.notificationType == NotificationType.replied ||
            n.notificationType == NotificationType.posted,
      NotificationFilter.mentions =>
        n.notificationType == NotificationType.mentioned ||
            n.notificationType == NotificationType.groupMentioned ||
            n.notificationType == NotificationType.quoted,
      NotificationFilter.likes =>
        n.notificationType == NotificationType.liked ||
            n.notificationType == NotificationType.likedConsolidated,
      NotificationFilter.messages =>
        n.notificationType == NotificationType.privateMessage ||
            n.notificationType == NotificationType.invitedToPrivateMessage ||
            n.notificationType == NotificationType.groupMessageSummary,
      NotificationFilter.other =>
        !_matchesFilter(n, NotificationFilter.replies) &&
            !_matchesFilter(n, NotificationFilter.mentions) &&
            !_matchesFilter(n, NotificationFilter.likes) &&
            !_matchesFilter(n, NotificationFilter.messages),
    };
  }
}

final notificationListProvider = StateNotifierProvider.family<
  NotificationListNotifier,
  NotificationListState,
  String
>(
  (ref, serverUrl) => NotificationListNotifier(
    ref.watch(discourseApiClientProvider),
    ref.watch(authServiceProvider),
    serverUrl,
  ),
);

class NotificationListNotifier extends StateNotifier<NotificationListState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final String _serverUrl;

  NotificationListNotifier(this._apiClient, this._authService, this._serverUrl)
    : super(const NotificationListState()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      final apiKey = await _authService.loadApiKey(_serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated');
        return;
      }

      final json = await _apiClient.fetchNotifications(_serverUrl, apiKey);

      final list =
          (json['notifications'] as List<dynamic>?)
              ?.map(
                (n) => DiscourseNotification.fromApiJson(
                  n as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [];

      state = state.copyWith(
        notifications: list,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await fetch();
  }

  Future<void> markAllRead() async {
    if (state.isMarkingRead) return;
    state = state.copyWith(isMarkingRead: true);

    try {
      final apiKey = await _authService.loadApiKey(_serverUrl);
      if (apiKey == null) {
        state = state.copyWith(isMarkingRead: false);
        return;
      }

      await _apiClient.markNotificationsRead(_serverUrl, apiKey);

      final updated =
          state.notifications.map((n) => n.copyWith(read: true)).toList();

      state = state.copyWith(
        notifications: updated,
        isMarkingRead: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isMarkingRead: false, error: e);
    }
  }

  void setFilter(NotificationFilter filter) {
    if (filter == state.activeFilter) return;
    state = state.copyWith(activeFilter: filter);
  }
}
