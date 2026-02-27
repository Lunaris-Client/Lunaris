import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/providers/message_bus_provider.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/providers/topic_detail_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/app/router.dart';
import 'package:lunaris/features/bookmarks/bookmark_reminder_picker.dart';
import 'package:lunaris/features/composer/reply_composer_screen.dart';
import 'package:lunaris/features/topic/post_item.dart';
import 'package:lunaris/features/topic/timeline_scrubber.dart';
import 'package:lunaris/ui/widgets/adaptive_dialog.dart';

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

String _formatEventRange(DateTime start, DateTime? end) {
  final startStr = '${start.month}/${start.day} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  if (end == null) return startStr;
  if (start.year == end.year && start.month == end.month && start.day == end.day) {
    return '$startStr – ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }
  return '$startStr – ${end.month}/${end.day} ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

class TopicViewScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final int topicId;
  final String? topicTitle;
  final Map<int, SiteCategory>? categoriesById;
  final bool embedded;
  final int? initialPostNumber;

  const TopicViewScreen({
    super.key,
    required this.serverUrl,
    required this.topicId,
    this.topicTitle,
    this.categoriesById,
    this.embedded = false,
    this.initialPostNumber,
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
  late final _messageBusNotifier = ref.read(messageBusProvider.notifier);
  bool _showScrollToTop = false;
  int _visiblePostIndex = 0;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ref.listenManual<MessageBusEvent?>(messageBusProvider, (prev, next) {
      if (next == null || next.type != 'topic_update') return;
      final data = next.data as Map<String, dynamic>;
      if (data['topic_id'] != widget.topicId) return;
      _notifier.handleTopicMessage(data);
    });
    _messageBusNotifier.subscribeToTopic(widget.topicId);
    if (widget.initialPostNumber != null) {
      _scheduleInitialScroll();
    }
  }

  @override
  void dispose() {
    _messageBusNotifier.unsubscribeFromTopic(widget.topicId);
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

  void _scheduleInitialScroll() {
    ref.listenManual(topicDetailProvider(_params), (prev, next) {
      if (_didInitialScroll) return;
      if (next.topic != null && next.topic!.posts.isNotEmpty) {
        _didInitialScroll = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _scrollToPostNumber(widget.initialPostNumber!);
          }
        });
      }
    });
  }

  void _showJumpToPostDialog(BuildContext context, int maxPostNumber) {
    final controller = TextEditingController();
    showAdaptiveDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog.adaptive(
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
            adaptiveAction(
              context: ctx,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            adaptiveAction(
              context: ctx,
              isDefault: true,
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

  void _confirmDeletePost(int postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _notifier.deletePost(postId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showFlagDialog(int postId) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SimpleDialog(
          title: const Text('Flag post'),
          children: [
            _FlagOption(
              icon: Icons.chat_bubble_outline,
              label: 'Off-topic',
              description: 'Not relevant to the current discussion',
              onTap: () {
                Navigator.of(ctx).pop();
                _flagPost(postId, 3);
              },
            ),
            _FlagOption(
              icon: Icons.warning_amber_rounded,
              label: 'Inappropriate',
              description: 'Not appropriate for this community',
              onTap: () {
                Navigator.of(ctx).pop();
                _flagPost(postId, 4);
              },
            ),
            _FlagOption(
              icon: Icons.report_outlined,
              label: 'Spam',
              description: 'This is an advertisement or vandalism',
              onTap: () {
                Navigator.of(ctx).pop();
                _flagPost(postId, 8);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _flagPost(int postId, int flagTypeId) async {
    try {
      final apiKey = await ref.read(authServiceProvider).loadApiKey(widget.serverUrl);
      if (apiKey == null) return;
      final apiClient = ref.read(discourseApiClientProvider);
      await apiClient.flagPost(widget.serverUrl, apiKey, postId, flagTypeId: flagTypeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post flagged'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to flag post: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
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

  bool get _isStaff {
    final server = ref.read(activeServerProvider);
    return server?.isAdmin == true || server?.isModerator == true;
  }

  List<Widget> _buildAppBarActions(TopicDetailState state, ThemeData theme) {
    if (state.topic == null) return [];
    final topic = state.topic!;
    return [
      IconButton(
        icon: Icon(
          topic.bookmarked
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: topic.bookmarked ? theme.colorScheme.primary : null,
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
              _showJumpToPostDialog(context, topic.highestPostNumber);
            case 'unread':
              _jumpToFirstUnread();
            case 'notification':
              _showNotificationLevelPicker(
                context,
                topic.notificationLevel,
              );
            case 'toggle_closed':
              _notifier.setTopicStatus('closed', !topic.closed);
            case 'toggle_archived':
              _notifier.setTopicStatus('archived', !topic.archived);
            case 'toggle_visible':
              _notifier.setTopicStatus('visible', !topic.visible);
            case 'toggle_pinned':
              _notifier.setTopicStatus('pinned', !topic.pinned);
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
                    notificationLevelIcon(topic.notificationLevel),
                  ),
                  title: Text(
                    notificationLevelLabel(topic.notificationLevel),
                  ),
                  dense: true,
                ),
              ),
              if (_isStaff) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'toggle_closed',
                  child: ListTile(
                    leading: Icon(topic.closed
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded),
                    title: Text(topic.closed ? 'Reopen' : 'Close'),
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_archived',
                  child: ListTile(
                    leading: Icon(topic.archived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded),
                    title: Text(topic.archived ? 'Unarchive' : 'Archive'),
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_visible',
                  child: ListTile(
                    leading: Icon(topic.visible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    title: Text(topic.visible ? 'Unlist' : 'List'),
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_pinned',
                  child: ListTile(
                    leading: Icon(topic.pinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded),
                    title: Text(topic.pinned ? 'Unpin' : 'Pin'),
                    dense: true,
                  ),
                ),
              ],
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
    final newCount = state.newPostIds.length;

    return Stack(
      children: [
        RefreshIndicator(
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
              acceptedAnswerPostNumber: topic.acceptedAnswerPostNumber,
              voteCount: topic.voteCount,
              canVote: topic.canVote,
              userVoted: topic.userVoted,
              onVoteTap: topic.canVote ? () => _notifier.toggleVote() : null,
              eventStartsAt: topic.eventStartsAt,
              eventEndsAt: topic.eventEndsAt,
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
                      isStaff: _isStaff,
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
                      onDeleteTap: () => _confirmDeletePost(post.id),
                      onRecoverTap: () => _notifier.recoverPost(post.id),
                      onFlagTap: () => _showFlagDialog(post.id),
                      onAcceptAnswerTap: (post.canAcceptAnswer || post.canUnacceptAnswer)
                          ? () => _notifier.toggleAcceptAnswer(post.id)
                          : null,
                      onUserTap: (username) => context.push(
                        '/user/$username',
                        extra: UserProfileRouteExtra(serverUrl: widget.serverUrl),
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
    ),
    if (newCount > 0)
      Positioned(
        top: 8,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            color: theme.colorScheme.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                _notifier.loadNewPosts();
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent + 200,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 16,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$newCount new ${newCount == 1 ? 'post' : 'posts'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ],
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
  final int? acceptedAnswerPostNumber;
  final int voteCount;
  final bool canVote;
  final bool userVoted;
  final VoidCallback? onVoteTap;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
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
    this.acceptedAnswerPostNumber,
    this.voteCount = 0,
    this.canVote = false,
    this.userVoted = false,
    this.onVoteTap,
    this.eventStartsAt,
    this.eventEndsAt,
    this.showActions = false,
    this.onBookmarkTap,
    this.onShareTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    final dotStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
    );
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: secondaryColor,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (category != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: parseHexColor(category!.color),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  category!.name,
                  style: metaStyle?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
              if (pinned) ...[
                const SizedBox(width: 8),
                Icon(Icons.push_pin_rounded, size: 13, color: secondaryColor),
              ],
              if (closed) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock_rounded, size: 13, color: secondaryColor),
              ],
              if (archived) ...[
                const SizedBox(width: 6),
                Icon(Icons.inventory_2_rounded, size: 13, color: secondaryColor),
              ],
              const Spacer(),
              Text(timeago.format(createdAt), style: metaStyle),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 10),
          _buildMetaStats(theme, metaStyle, dotStyle),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((tag) {
                return Text(
                  '#$tag',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    fontSize: 11,
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
                  icon: bookmarked
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
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildMetaStats(ThemeData theme, TextStyle? metaStyle, TextStyle? dotStyle) {
    final parts = <InlineSpan>[
      TextSpan(text: '${formatCount(replyCount)} replies'),
      TextSpan(text: '${formatCount(likeCount)} likes'),
      TextSpan(text: '${formatCount(views)} views'),
    ];
    if (acceptedAnswerPostNumber != null) {
      parts.add(const TextSpan(
        text: 'solved',
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
      ));
    }
    if (voteCount > 0 || canVote) {
      final voteStyle = userVoted
          ? (metaStyle ?? const TextStyle()).copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.w600)
          : metaStyle;
      if (canVote && onVoteTap != null) {
        parts.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: onVoteTap,
            child: Text('$voteCount votes', style: voteStyle),
          ),
        ));
      } else {
        parts.add(TextSpan(
          text: '$voteCount votes',
          style: userVoted
              ? TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)
              : null,
        ));
      }
    }
    if (eventStartsAt != null) {
      parts.add(TextSpan(
        text: _formatEventRange(eventStartsAt!, eventEndsAt),
        style: TextStyle(color: theme.colorScheme.tertiary),
      ));
    }
    final dot = TextSpan(text: ' · ', style: dotStyle);
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) spans.add(dot);
      spans.add(parts[i]);
    }
    return Text.rich(
      TextSpan(children: spans),
      style: metaStyle,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        mouseCursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      ),
    );
  }
}

class _FlagOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _FlagOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(description),
      onTap: onTap,
    );
  }
}
