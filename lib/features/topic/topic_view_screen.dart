import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/providers/topic_detail_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/bookmarks/bookmark_reminder_picker.dart';
import 'package:lunaris/features/composer/reply_composer_screen.dart';
import 'package:lunaris/features/topic/post_item.dart';
import 'package:lunaris/features/topic/timeline_scrubber.dart';

IconData notificationLevelIcon(int? level) {
  return switch (level) {
    0 => Icons.notifications_off_outlined,
    2 => Icons.visibility_outlined,
    3 => Icons.notifications_active_rounded,
    _ => Icons.notifications_none_rounded,
  };
}

String notificationLevelLabel(int? level) {
  return switch (level) {
    0 => 'Muted',
    2 => 'Tracking',
    3 => 'Watching',
    _ => 'Normal',
  };
}

class TopicViewScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final int topicId;
  final String? topicTitle;
  final Map<int, SiteCategory>? categoriesById;
  final bool embedded;

  const TopicViewScreen({
    super.key,
    required this.serverUrl,
    required this.topicId,
    this.topicTitle,
    this.categoriesById,
    this.embedded = false,
  });

  @override
  ConsumerState<TopicViewScreen> createState() => _TopicViewScreenState();
}

class _TopicViewScreenState extends ConsumerState<TopicViewScreen> {
  final _scrollController = ScrollController();
  final _postKeys = <int, GlobalKey>{};
  late final _params = TopicDetailParams(
    serverUrl: widget.serverUrl,
    topicId: widget.topicId,
  );
  bool _showScrollToTop = false;
  int _visiblePostIndex = 0;

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
    final showFab = _scrollController.position.pixels > 300;
    if (showFab != _showScrollToTop) {
      setState(() => _showScrollToTop = showFab);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _notifier.loadMorePosts();
    }

    _updateVisiblePostIndex();
  }

  void _updateVisiblePostIndex() {
    final state = ref.read(topicDetailProvider(_params));
    if (state.topic == null) return;
    final posts = state.topic!.posts;

    int best = 0;
    for (int i = 0; i < posts.length; i++) {
      final key = _postKeys[posts[i].id];
      if (key?.currentContext == null) continue;
      final box = key!.currentContext!.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy <= 120) best = i; // 120px accounts for app bar height
    }

    if (best != _visiblePostIndex) {
      setState(() => _visiblePostIndex = best);
      _notifier.updateCurrentPostIndex(best);
    }
  }

  void _scrollToPostNumber(int postNumber) {
    final state = ref.read(topicDetailProvider(_params));
    if (state.topic == null) return;

    final idx = state.topic!.posts.indexWhere(
      (p) => p.postNumber == postNumber,
    );
    if (idx < 0) return;

    final post = state.topic!.posts[idx];
    final key = _postKeys[post.id];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    } else {
      _scrollController.animateTo(
        idx * 200.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToIndex(int index) {
    final state = ref.read(topicDetailProvider(_params));
    if (state.topic == null) return;
    final posts = state.topic!.posts;
    if (index < 0 || index >= posts.length) return;
    _scrollToPostNumber(posts[index].postNumber);
  }

  void _jumpToFirstUnread() {
    final unread = _notifier.firstUnreadPostNumber;
    if (unread != null) {
      _scrollToPostNumber(unread);
    }
  }

  void _showJumpToPostDialog(BuildContext context, int maxPostNumber) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Jump to post'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: '1 - $maxPostNumber',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final n = int.tryParse(value);
              if (n != null && n >= 1 && n <= maxPostNumber) {
                Navigator.pop(ctx);
                _scrollToPostNumber(n);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(controller.text);
                if (n != null && n >= 1 && n <= maxPostNumber) {
                  Navigator.pop(ctx);
                  _scrollToPostNumber(n);
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  TopicDetailNotifier get _notifier =>
      ref.read(topicDetailProvider(_params).notifier);

  void _openReplyComposer({
    int? replyToPostNumber,
    String? username,
    String? quoted,
  }) {
    final state = ref.read(topicDetailProvider(_params));
    final title = state.topic?.title ?? widget.topicTitle ?? 'Topic';
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => ReplyComposerScreen(
              serverUrl: widget.serverUrl,
              topicId: widget.topicId,
              topicTitle: title,
              replyToPostNumber: replyToPostNumber,
              replyToUsername: username,
              quotedText: quoted,
            ),
      ),
    );
  }

  Widget? _buildTimelineScrubber(TopicDetailState state) {
    if (state.topic == null || state.topic!.posts.length <= 3) return null;
    return TimelineScrubber(
      currentIndex: _visiblePostIndex,
      totalPosts: state.topic!.posts.length,
      lastReadPostNumber: state.topic!.lastReadPostNumber,
      highestPostNumber: state.topic!.highestPostNumber,
      onScrub: _scrollToIndex,
    );
  }

  String get _topicUrl => '${widget.serverUrl}/t/${widget.topicId}';

  void _sharePost(int postNumber) {
    _showShareSheet(context, '$_topicUrl/$postNumber');
  }

  void _shareTopic() {
    _showShareSheet(context, _topicUrl);
  }

  Future<void> _bookmarkWithReminder(int postId) async {
    final result = await showBookmarkReminderPicker(context);
    if (result == null) return;

    _notifier.bookmarkWithReminder(
      postId,
      name: result.name,
      reminderAt: result.reminderAt?.toUtc().toIso8601String(),
      autoDeletePreference: result.autoDeletePreference,
    );
  }

  static void _showShareSheet(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Share', style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  url,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy link'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser_rounded),
                title: const Text('Open in browser'),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationLevelPicker(BuildContext context, int? currentLevel) {
    const levels = [
      (
        0,
        'Muted',
        Icons.notifications_off_outlined,
        'Suppress all notifications',
      ),
      (
        1,
        'Normal',
        Icons.notifications_none_rounded,
        'Notify only if mentioned',
      ),
      (2, 'Tracking', Icons.visibility_outlined, 'Show unread count'),
      (
        3,
        'Watching',
        Icons.notifications_active_rounded,
        'Notify on every new post',
      ),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Notification Level',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              ...levels.map((l) {
                final (level, label, icon, description) = l;
                final selected = currentLevel == level;
                return ListTile(
                  leading: Icon(
                    icon,
                    color: selected ? theme.colorScheme.primary : null,
                  ),
                  title: Text(
                    label,
                    style:
                        selected
                            ? TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            )
                            : null,
                  ),
                  subtitle: Text(description),
                  trailing:
                      selected
                          ? Icon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                          : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _notifier.setNotificationLevel(level);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(topicDetailProvider(_params));
    final theme = Theme.of(context);

    final scrubber = _buildTimelineScrubber(state);

    if (widget.embedded) {
      return Stack(
        children: [
          Row(
            children: [
              Expanded(child: _buildBody(state, theme)),
              if (scrubber != null) scrubber,
            ],
          ),
          Positioned(
            right: 56,
            bottom: 12,
            child: _buildNavigationFab(state, theme),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.topic?.title ?? widget.topicTitle ?? 'Topic',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: _buildAppBarActions(state, theme),
      ),
      body: Row(
        children: [
          Expanded(child: _buildBody(state, theme)),
          if (scrubber != null) scrubber,
        ],
      ),
      floatingActionButton: _buildNavigationFab(state, theme),
    );
  }

  List<Widget> _buildAppBarActions(TopicDetailState state, ThemeData theme) {
    if (state.topic == null) return [];
    return [
      IconButton(
        icon: Icon(
          state.topic!.bookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: state.topic!.bookmarked ? theme.colorScheme.primary : null,
        ),
        onPressed: () => _notifier.toggleTopicBookmark(),
      ),
      IconButton(
        icon: const Icon(Icons.share_outlined),
        onPressed: _shareTopic,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (value) {
          switch (value) {
            case 'jump':
              _showJumpToPostDialog(context, state.topic!.highestPostNumber);
            case 'unread':
              _jumpToFirstUnread();
            case 'notification':
              _showNotificationLevelPicker(
                context,
                state.topic!.notificationLevel,
              );
          }
        },
        itemBuilder:
            (ctx) => [
              const PopupMenuItem(
                value: 'jump',
                child: ListTile(
                  leading: Icon(Icons.tag_rounded),
                  title: Text('Jump to post'),
                  dense: true,
                ),
              ),
              if (_notifier.firstUnreadPostNumber != null)
                const PopupMenuItem(
                  value: 'unread',
                  child: ListTile(
                    leading: Icon(Icons.mark_chat_unread_outlined),
                    title: Text('First unread'),
                    dense: true,
                  ),
                ),
              PopupMenuItem(
                value: 'notification',
                child: ListTile(
                  leading: Icon(
                    notificationLevelIcon(state.topic!.notificationLevel),
                  ),
                  title: Text(
                    notificationLevelLabel(state.topic!.notificationLevel),
                  ),
                  dense: true,
                ),
              ),
            ],
      ),
    ];
  }

  Widget _buildBody(TopicDetailState state, ThemeData theme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.topic == null) {
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
              Text('Failed to load topic', style: theme.textTheme.titleMedium),
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
                onPressed: () => _notifier.refresh(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final topic = state.topic!;
    final category = widget.categoriesById?[topic.categoryId];

    return RefreshIndicator(
      onRefresh: () => _notifier.refresh(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _TopicHeader(
              title: topic.title,
              category: category,
              tags: topic.tags,
              views: topic.views,
              likeCount: topic.likeCount,
              replyCount: topic.replyCount,
              createdAt: topic.createdAt,
              closed: topic.closed,
              pinned: topic.pinned,
              archived: topic.archived,
              bookmarked: topic.bookmarked,
              notificationLevel: topic.notificationLevel,
              showActions: widget.embedded,
              onBookmarkTap: () => _notifier.toggleTopicBookmark(),
              onShareTap: _shareTopic,
              onNotificationTap:
                  () => _showNotificationLevelPicker(
                    context,
                    topic.notificationLevel,
                  ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < topic.posts.length) {
                final post = topic.posts[index];
                _postKeys.putIfAbsent(post.id, () => GlobalKey());
                return Column(
                  key: _postKeys[post.id],
                  children: [
                    PostItem(
                      post: post,
                      serverUrl: widget.serverUrl,
                      onLikeTap: () => _notifier.toggleLike(post.id),
                      onBookmarkTap: () => _notifier.toggleBookmark(post.id),
                      onBookmarkLongPress: () => _bookmarkWithReminder(post.id),
                      onShareTap: () => _sharePost(post.postNumber),
                      onReplyToTap: _scrollToPostNumber,
                      onReplyTap:
                          () => _openReplyComposer(
                            replyToPostNumber: post.postNumber,
                            username: post.username,
                          ),
                    ),
                    if (index < topic.posts.length - 1)
                      const Divider(height: 1, indent: 62),
                  ],
                );
              }

              if (state.isLoadingMore) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return const SizedBox.shrink();
            }, childCount: topic.posts.length + (state.isLoadingMore ? 1 : 0)),
          ),
          if (!state.hasMorePosts && topic.posts.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    '${topic.postsCount} ${topic.postsCount == 1 ? 'post' : 'posts'} in this topic',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildNavigationFab(TopicDetailState state, ThemeData theme) {
    final hasUnread =
        state.topic != null && _notifier.firstUnreadPostNumber != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showScrollToTop && hasUnread)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'fab_unread',
              backgroundColor: theme.colorScheme.tertiaryContainer,
              onPressed: _jumpToFirstUnread,
              child: Icon(
                Icons.mark_chat_unread_outlined,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        if (_showScrollToTop)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'fab_top',
              onPressed:
                  () => _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                  ),
              child: const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        if (state.topic != null)
          FloatingActionButton(
            heroTag: 'fab_reply',
            onPressed: () => _openReplyComposer(),
            child: const Icon(Icons.edit_rounded),
          ),
      ],
    );
  }
}

class _TopicHeader extends StatelessWidget {
  final String title;
  final SiteCategory? category;
  final List<String> tags;
  final int views;
  final int likeCount;
  final int replyCount;
  final DateTime createdAt;
  final bool closed;
  final bool pinned;
  final bool archived;
  final bool bookmarked;
  final int? notificationLevel;
  final bool showActions;
  final VoidCallback? onBookmarkTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onNotificationTap;

  const _TopicHeader({
    required this.title,
    this.category,
    required this.tags,
    required this.views,
    required this.likeCount,
    required this.replyCount,
    required this.createdAt,
    required this.closed,
    required this.pinned,
    required this.archived,
    this.bookmarked = false,
    this.notificationLevel,
    this.showActions = false,
    this.onBookmarkTap,
    this.onShareTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (category != null) ...[
                Builder(
                  builder: (_) {
                    final catColor = parseHexColor(category!.color);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category!.name,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: catColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (pinned)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (closed)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (archived)
                Icon(
                  Icons.inventory_2_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _MetaChip(
                icon: Icons.remove_red_eye_outlined,
                label: formatCount(views),
              ),
              _MetaChip(
                icon: Icons.favorite_border_rounded,
                label: formatCount(likeCount),
              ),
              _MetaChip(
                icon: Icons.reply_rounded,
                label: formatCount(replyCount),
              ),
              _MetaChip(
                icon: Icons.schedule_rounded,
                label: timeago.format(createdAt),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _TopicActionChip(
                  icon:
                      bookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                  label: 'Bookmark',
                  active: bookmarked,
                  onTap: onBookmarkTap,
                ),
                const SizedBox(width: 8),
                _TopicActionChip(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: onShareTap,
                ),
                const SizedBox(width: 8),
                _TopicActionChip(
                  icon: notificationLevelIcon(notificationLevel),
                  label: notificationLevelLabel(notificationLevel),
                  active: notificationLevel != null && notificationLevel! > 1,
                  onTap: onNotificationTap,
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TopicActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _TopicActionChip({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              active
                  ? theme.colorScheme.primary.withValues(alpha: 0.1)
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
