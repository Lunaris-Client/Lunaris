import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/chat_channel.dart';
import 'package:lunaris/core/providers/chat_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/utils/html_entity_decoder.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatChannelListView extends ConsumerWidget {
  final String serverUrl;
  final ValueChanged<ChatChannel>? onChannelSelected;
  final int? selectedChannelId;
  final VoidCallback? onNewChat;

  const ChatChannelListView({
    super.key,
    required this.serverUrl,
    this.onChannelSelected,
    this.selectedChannelId,
    this.onNewChat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatChannelListProvider(serverUrl));
    final theme = Theme.of(context);

    if (state.isLoading && state.channels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.channels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: theme.colorScheme.error.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text('Failed to load chat', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                _errorText(state.error),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(chatChannelListProvider(serverUrl).notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text('No chat channels', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Chat may not be enabled on this server',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final publicChannels = state.publicChannels;
    final dms = state.directMessages;
    final currentUserId = ref.watch(activeServerProvider)?.userId;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(chatChannelListProvider(serverUrl).notifier).refresh(),
        child: ListView(
          children: [
            if (publicChannels.isNotEmpty) ...[
              _SectionHeader(title: 'Channels', count: publicChannels.length),
              for (final channel in publicChannels)
                _ChannelTile(
                  channel: channel,
                  serverUrl: serverUrl,
                  currentUserId: currentUserId,
                  isSelected: selectedChannelId == channel.id,
                  onTap: () => onChannelSelected?.call(channel),
                ),
            ],
            if (dms.isNotEmpty) ...[
              _SectionHeader(title: 'Direct Messages', count: dms.length),
              for (final dm in dms)
                _ChannelTile(
                  channel: dm,
                  serverUrl: serverUrl,
                  currentUserId: currentUserId,
                  isSelected: selectedChannelId == dm.id,
                  onTap: () => onChannelSelected?.call(dm),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: onNewChat != null
          ? FloatingActionButton(
              onPressed: onNewChat,
              tooltip: 'New message',
              child: const Icon(Icons.edit_rounded),
            )
          : null,
    );
  }

  String _errorText(Object? error) {
    final msg = error.toString();
    if (msg.contains('404')) return 'Chat plugin may not be installed';
    if (msg.contains('403')) return 'You don\'t have access to chat';
    return msg;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final ChatChannel channel;
  final String serverUrl;
  final int? currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.channel,
    required this.serverUrl,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = (channel.unreadCount ?? 0) > 0;

    return ListTile(
      selected: isSelected,
      leading: _buildAvatar(theme),
      title: Text(
        channel.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: hasUnread
            ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
            : null,
      ),
      subtitle: channel.lastMessage != null
          ? Text.rich(
              TextSpan(children: _buildPreviewSpans(theme)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : channel.description != null
              ? Text(
                  decodeHtmlEntities(channel.description!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (channel.lastMessage != null)
            Text(
              timeago.format(channel.lastMessage!.createdAt, locale: 'en_short'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: hasUnread
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            Badge.count(
              count: channel.unreadCount!,
              backgroundColor: (channel.unreadMentions ?? 0) > 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }

  List<InlineSpan> _buildPreviewSpans(ThemeData theme) {
    final msg = channel.lastMessage!;
    final isOwn = currentUserId != null && msg.userId == currentUserId;
    final senderName = isOwn ? 'You' : msg.username;
    final rawText = msg.excerpt ?? msg.message;
    final text = decodeHtmlEntities(rawText);

    return [
      if (senderName != null)
        TextSpan(
          text: '$senderName: ',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      TextSpan(
        text: text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  Widget _buildAvatar(ThemeData theme) {
    if (channel.isDirectMessage && channel.dmUsers.isNotEmpty) {
      if (channel.dmUsers.length == 1) {
        final user = channel.dmUsers.first;
        return _dmAvatar(user, 40);
      }
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            Positioned(
              bottom: 0,
              left: 0,
              child: _dmAvatar(channel.dmUsers[0], 28),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: _dmAvatar(channel.dmUsers[1], 24),
              ),
            ),
          ],
        ),
      );
    }

    return CircleAvatar(
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Icon(
        Icons.tag_rounded,
        color: theme.colorScheme.onPrimaryContainer,
        size: 20,
      ),
    );
  }

  Widget _dmAvatar(DmUser user, double size) {
    final template = user.avatarTemplate;
    if (template != null) {
      final url = template.startsWith('http')
          ? template.replaceAll('{size}', size.toInt().toString())
          : '$serverUrl${template.replaceAll('{size}', size.toInt().toString())}';
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      child: Text(
        user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
        style: TextStyle(fontSize: size * 0.4),
      ),
    );
  }
}
