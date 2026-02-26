import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/providers/pm_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

class PmInboxView extends ConsumerStatefulWidget {
  final String serverUrl;
  final String username;
  final ValueChanged<Topic>? onTopicSelected;
  final int? selectedTopicId;

  const PmInboxView({
    super.key,
    required this.serverUrl,
    required this.username,
    this.onTopicSelected,
    this.selectedTopicId,
  });

  @override
  ConsumerState<PmInboxView> createState() => _PmInboxViewState();
}

class _PmInboxViewState extends ConsumerState<PmInboxView> {
  final _scrollController = ScrollController();

  PmListParams get _params => PmListParams(
        serverUrl: widget.serverUrl,
        username: widget.username,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(pmListProvider(_params).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pmListProvider(_params));
    final theme = Theme.of(context);

    if (state.isLoading && state.topics.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.topics.isEmpty) {
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
              Text('Failed to load messages',
                  style: theme.textTheme.titleMedium),
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
                onPressed: () =>
                    ref.read(pmListProvider(_params).notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mail_outline_rounded,
              size: 48,
              color:
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(pmListProvider(_params).notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.topics.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          if (index == state.topics.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final topic = state.topics[index];
          return _PmCard(
            topic: topic,
            users: state.users,
            serverUrl: widget.serverUrl,
            selected: widget.selectedTopicId == topic.id,
            onTap: widget.onTopicSelected != null
                ? () => widget.onTopicSelected!(topic)
                : null,
          );
        },
      ),
    );
  }
}

class _PmCard extends StatelessWidget {
  final Topic topic;
  final Map<int, TopicUser> users;
  final String serverUrl;
  final bool selected;
  final VoidCallback? onTap;

  const _PmCard({
    required this.topic,
    required this.users,
    required this.serverUrl,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = topic.unreadPosts > 0;

    final participantAvatars = topic.posters
        .map((p) => users[p.userId])
        .where((u) => u != null)
        .take(3)
        .toList();

    return ListTile(
      selected: selected,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: participantAvatars.isNotEmpty
          ? _buildAvatarStack(participantAvatars.cast<TopicUser>())
          : CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.mail_rounded,
                  color: theme.colorScheme.onPrimaryContainer, size: 20),
            ),
      title: Text(
        topic.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Text(
              '${topic.postsCount} ${topic.postsCount == 1 ? 'reply' : 'replies'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeago.format(topic.bumpedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      trailing: hasUnread
          ? Badge.count(
              count: topic.unreadPosts,
              child: const SizedBox.shrink(),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildAvatarStack(List<TopicUser> avatarUsers) {
    if (avatarUsers.length == 1) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(
          resolveAvatarUrl(serverUrl, avatarUsers.first.avatarTemplate, size: 40),
        ),
      );
    }
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          for (var i = 0; i < avatarUsers.length && i < 3; i++)
            Positioned(
              left: i * 10.0,
              child: CircleAvatar(
                radius: 14,
                backgroundImage: NetworkImage(
                  resolveAvatarUrl(serverUrl, avatarUsers[i].avatarTemplate, size: 40),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
