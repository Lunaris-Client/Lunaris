import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lunaris/core/models/discourse_notification.dart';
import 'package:lunaris/core/providers/notification_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class NotificationListView extends ConsumerWidget {
  final String serverUrl;
  final void Function(int topicId, int? postNumber)? onNotificationTap;
  final void Function(int channelId)? onChatNotificationTap;

  const NotificationListView({
    super.key,
    required this.serverUrl,
    this.onNotificationTap,
    this.onChatNotificationTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationListProvider(serverUrl));
    final notifier = ref.read(notificationListProvider(serverUrl).notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        _FilterBar(
          activeFilter: state.activeFilter,
          onFilterChanged: notifier.setFilter,
        ),
        Expanded(child: _buildBody(state, notifier, theme)),
      ],
    );
  }

  Widget _buildBody(
    NotificationListState state,
    NotificationListNotifier notifier,
    ThemeData theme,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: theme.colorScheme.error.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load notifications',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${state.error}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => notifier.refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = state.filtered;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              state.activeFilter == NotificationFilter.all
                  ? 'No notifications yet'
                  : 'No ${state.activeFilter.name} notifications',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final notification = filtered[index];
          return _NotificationTile(
            notification: notification,
            serverUrl: serverUrl,
            onTap: () {
              _handleNotificationTap(notification);
            },
          );
        },
      ),
    );
  }

  void _handleNotificationTap(DiscourseNotification notification) {
    final type = notification.notificationType;

    if (type == NotificationType.chatMention ||
        type == NotificationType.chatGroupMention ||
        type == NotificationType.chatInvitation ||
        type == NotificationType.chatWatchedThread) {
      final channelId = notification.data.chatChannelId;
      if (channelId != null) {
        onChatNotificationTap?.call(channelId);
      }
      return;
    }

    if (notification.topicId != null) {
      onNotificationTap?.call(
        notification.topicId!,
        notification.postNumber,
      );
    }
  }
}

class _FilterBar extends StatelessWidget {
  final NotificationFilter activeFilter;
  final ValueChanged<NotificationFilter> onFilterChanged;

  const _FilterBar({required this.activeFilter, required this.onFilterChanged});

  static const _filters = [
    (NotificationFilter.all, 'All'),
    (NotificationFilter.replies, 'Replies'),
    (NotificationFilter.mentions, 'Mentions'),
    (NotificationFilter.likes, 'Likes'),
    (NotificationFilter.messages, 'Messages'),
    (NotificationFilter.other, 'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final (filter, label) = _filters[index];
              final selected = activeFilter == filter;
              return Center(
                child: Material(
                  color: selected
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => onFilterChanged(filter),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final DiscourseNotification notification;
  final String serverUrl;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.notification,
    required this.serverUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !notification.read;
    final (icon, iconColor) = _notificationIcon(notification, theme);

    final title = _buildTitle(notification);
    final topicTitle =
        notification.fancyTitle ?? notification.data.topicTitle ?? '';

    return ListTile(
      onTap: onTap,
      tileColor:
          unread ? theme.colorScheme.primary.withValues(alpha: 0.06) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildAvatar(theme),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
          ),
        ],
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          topicTitle.isNotEmpty
              ? Text(
                topicTitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
              : null,
      trailing: Text(
        timeago.format(notification.createdAt),
        style: theme.textTheme.labelSmall?.copyWith(
          color:
              unread
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final template = notification.actingUserAvatarTemplate;
    if (template != null && template.isNotEmpty) {
      final avatarUrl = resolveAvatarUrl(serverUrl, template, size: 40);
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
        backgroundColor: theme.colorScheme.primaryContainer,
      );
    }

    final username =
        notification.data.displayUsername ?? notification.data.originalUsername;
    if (username != null && username.isNotEmpty) {
      final avatarUrl = resolveAvatarUrl(
        serverUrl,
        '/letter_avatar_proxy/v4/letter/${username[0].toLowerCase()}/96/{size}.png',
      );
      return CircleAvatar(
        radius: 20,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
        backgroundColor: theme.colorScheme.primaryContainer,
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Icon(
        Icons.person_rounded,
        size: 20,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  String _buildTitle(DiscourseNotification n) {
    final user = n.data.displayUsername ??
        n.actingUserName ??
        n.data.originalUsername ??
        n.data.mentionedByUsername ??
        n.data.invitedByUsername ??
        n.data.username ??
        'Someone';
    final channelName = n.data.chatChannelTitle;
    return switch (n.notificationType) {
      NotificationType.mentioned => '$user mentioned you',
      NotificationType.replied => '$user replied',
      NotificationType.quoted => '$user quoted you',
      NotificationType.edited => '$user edited a post',
      NotificationType.liked => '$user liked your post',
      NotificationType.privateMessage => '$user sent you a message',
      NotificationType.invitedToPrivateMessage =>
        '$user invited you to a message',
      NotificationType.posted => '$user posted',
      NotificationType.movedPost => '$user moved your post',
      NotificationType.linked => '$user linked to your post',
      NotificationType.grantedBadge =>
        'Earned \'${n.data.badgeName ?? 'badge'}\'',
      NotificationType.invitedToTopic => '$user invited you to a topic',
      NotificationType.groupMentioned =>
        '$user mentioned ${n.data.groupName ?? 'your group'}',
      NotificationType.watchingFirstPost => 'New topic in watched category',
      NotificationType.topicReminder => 'Topic reminder',
      NotificationType.likedConsolidated =>
        '${n.data.count ?? 0} people liked your post',
      NotificationType.bookmarkReminder => 'Bookmark reminder',
      NotificationType.reaction => '$user reacted to your post',
      NotificationType.groupMessageSummary =>
        '${n.data.count ?? 0} messages in ${n.data.groupName ?? 'group'}',
      NotificationType.chatMention =>
        channelName != null
            ? '$user mentioned you in "$channelName"'
            : '$user mentioned you in chat',
      NotificationType.chatGroupMention =>
        channelName != null
            ? '$user mentioned you in "$channelName"'
            : '$user mentioned your group in chat',
      NotificationType.chatInvitation =>
        channelName != null
            ? '$user invited you to "$channelName"'
            : '$user invited you to a chat',
      NotificationType.chatWatchedThread =>
        '$user replied in a thread you\'re watching',
      _ => '$user sent a notification',
    };
  }

  static (IconData, Color) _notificationIcon(
    DiscourseNotification n,
    ThemeData theme,
  ) {
    return switch (n.notificationType) {
      NotificationType.mentioned || NotificationType.groupMentioned => (
        Icons.alternate_email_rounded,
        theme.colorScheme.primary,
      ),
      NotificationType.replied || NotificationType.posted => (
        Icons.reply_rounded,
        theme.colorScheme.primary,
      ),
      NotificationType.quoted => (
        Icons.format_quote_rounded,
        theme.colorScheme.primary,
      ),
      NotificationType.liked || NotificationType.likedConsolidated => (
        Icons.favorite_rounded,
        Colors.red,
      ),
      NotificationType.privateMessage ||
      NotificationType.invitedToPrivateMessage ||
      NotificationType.groupMessageSummary => (
        Icons.mail_rounded,
        theme.colorScheme.tertiary,
      ),
      NotificationType.grantedBadge => (
        Icons.emoji_events_rounded,
        Colors.amber,
      ),
      NotificationType.watchingFirstPost => (
        Icons.visibility_rounded,
        theme.colorScheme.secondary,
      ),
      NotificationType.bookmarkReminder || NotificationType.topicReminder => (
        Icons.schedule_rounded,
        theme.colorScheme.secondary,
      ),
      NotificationType.edited => (
        Icons.edit_rounded,
        theme.colorScheme.onSurfaceVariant,
      ),
      NotificationType.movedPost => (
        Icons.drive_file_move_rounded,
        theme.colorScheme.onSurfaceVariant,
      ),
      NotificationType.linked => (
        Icons.link_rounded,
        theme.colorScheme.primary,
      ),
      NotificationType.reaction => (Icons.add_reaction_rounded, Colors.orange),
      _ => (Icons.notifications_rounded, theme.colorScheme.onSurfaceVariant),
    };
  }
}
