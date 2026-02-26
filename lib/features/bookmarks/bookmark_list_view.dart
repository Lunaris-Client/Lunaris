import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lunaris/app/router.dart';
import 'package:lunaris/core/models/bookmark.dart';
import 'package:lunaris/core/providers/bookmark_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/ui/widgets/adaptive_dialog.dart';

class BookmarkListView extends ConsumerStatefulWidget {
  final String serverUrl;
  final String username;
  final ValueChanged<Bookmark>? onBookmarkSelected;

  const BookmarkListView({
    super.key,
    required this.serverUrl,
    required this.username,
    this.onBookmarkSelected,
  });

  @override
  ConsumerState<BookmarkListView> createState() => _BookmarkListViewState();
}

class _BookmarkListViewState extends ConsumerState<BookmarkListView> {
  final _scrollController = ScrollController();

  BookmarkListParams get _params => BookmarkListParams(
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
      ref.read(bookmarkListProvider(_params).notifier).loadMore();
    }
  }

  void _navigateToTopic(Bookmark bookmark) {
    if (bookmark.topicId == null) return;
    if (widget.onBookmarkSelected != null) {
      widget.onBookmarkSelected!(bookmark);
      return;
    }
    context.push(
      '/topic/${bookmark.topicId}',
      extra: TopicRouteExtra(serverUrl: widget.serverUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookmarkListProvider(_params));
    final theme = Theme.of(context);

    if (state.isLoading && state.bookmarks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.bookmarks.isEmpty) {
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
              Text('Failed to load bookmarks',
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
                    ref.read(bookmarkListProvider(_params).notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No bookmarks yet',
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
          ref.read(bookmarkListProvider(_params).notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.bookmarks.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          if (index == state.bookmarks.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final bookmark = state.bookmarks[index];
          return _BookmarkCard(
            bookmark: bookmark,
            serverUrl: widget.serverUrl,
            onTap: () => _navigateToTopic(bookmark),
            onDelete: () => _confirmDelete(bookmark),
          );
        },
      ),
    );
  }

  void _confirmDelete(Bookmark bookmark) async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Remove bookmark?',
      content: bookmark.title,
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed == true) {
      ref
          .read(bookmarkListProvider(_params).notifier)
          .deleteBookmark(bookmark.id);
    }
  }
}

class _BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final String serverUrl;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _BookmarkCard({
    required this.bookmark,
    required this.serverUrl,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = bookmark.avatarTemplate != null
        ? resolveAvatarUrl(serverUrl, bookmark.avatarTemplate!, size: 40)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: avatarUrl != null
          ? CircleAvatar(
              radius: 20,
              backgroundImage: CachedNetworkImageProvider(avatarUrl),
            )
          : CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.bookmark_rounded,
                  color: theme.colorScheme.onPrimaryContainer, size: 20),
            ),
      title: Text(
        bookmark.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: _buildSubtitle(theme),
      trailing: _buildTrailing(theme),
      onTap: onTap,
      onLongPress: onDelete,
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    final parts = <Widget>[];

    if (bookmark.name != null && bookmark.name!.isNotEmpty) {
      parts.add(Text(
        bookmark.name!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ));
    }

    final meta = <String>[];
    if (bookmark.username != null) meta.add(bookmark.username!);
    if (bookmark.createdAt != null) meta.add(timeago.format(bookmark.createdAt!));
    if (meta.isNotEmpty) {
      parts.add(Text(
        meta.join(' \u00b7 '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ));
    }

    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: parts,
      ),
    );
  }

  Widget? _buildTrailing(ThemeData theme) {
    final indicators = <Widget>[];

    if (bookmark.pinned) {
      indicators.add(Icon(
        Icons.push_pin_rounded,
        size: 16,
        color: theme.colorScheme.primary,
      ));
    }

    if (bookmark.reminderAt != null) {
      indicators.add(Icon(
        Icons.alarm_rounded,
        size: 16,
        color: theme.colorScheme.tertiary,
      ));
    }

    if (indicators.isEmpty) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: indicators,
    );
  }
}
