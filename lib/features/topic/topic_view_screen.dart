import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/providers/topic_detail_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/topic/post_item.dart';

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
  late final _params = TopicDetailParams(
    serverUrl: widget.serverUrl,
    topicId: widget.topicId,
  );
  bool _showScrollToTop = false;

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
      ref.read(topicDetailProvider(_params).notifier).loadMorePosts();
    }
  }

  void _scrollToPostNumber(int postNumber) {
    final state = ref.read(topicDetailProvider(_params));
    if (state.topic == null) return;

    final idx =
        state.topic!.posts.indexWhere((p) => p.postNumber == postNumber);
    if (idx >= 0) {
      _scrollController.animateTo(
        idx * 200.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(topicDetailProvider(_params));
    final theme = Theme.of(context);

    if (widget.embedded) {
      return Stack(
        children: [
          _buildBody(state, theme),
          Positioned(
            right: 12,
            bottom: 12,
            child: _buildScrollToTopFab(theme) ?? const SizedBox.shrink(),
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
      ),
      body: _buildBody(state, theme),
      floatingActionButton: _buildScrollToTopFab(theme),
    );
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
              Icon(Icons.cloud_off_rounded, size: 48,
                  color: theme.colorScheme.error.withValues(alpha: 0.6)),
              const SizedBox(height: 12),
              Text('Failed to load topic',
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
                    ref.read(topicDetailProvider(_params).notifier).refresh(),
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
      onRefresh: () =>
          ref.read(topicDetailProvider(_params).notifier).refresh(),
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
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < topic.posts.length) {
                  return Column(
                    children: [
                      PostItem(
                        post: topic.posts[index],
                        serverUrl: widget.serverUrl,
                        onReplyToTap: _scrollToPostNumber,
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
              },
              childCount: topic.posts.length + (state.isLoadingMore ? 1 : 0),
            ),
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

  Widget? _buildScrollToTopFab(ThemeData theme) {
    if (!_showScrollToTop) return null;
    return FloatingActionButton.small(
      onPressed: () => _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      ),
      child: const Icon(Icons.arrow_upward_rounded),
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
                Builder(builder: (_) {
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
                }),
                const SizedBox(width: 8),
              ],
              if (pinned)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin_rounded, size: 14,
                      color: theme.colorScheme.primary),
                ),
              if (closed)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.lock_rounded, size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              if (archived)
                Icon(Icons.inventory_2_rounded, size: 14,
                    color: theme.colorScheme.onSurfaceVariant),
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
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
        Icon(icon, size: 14,
            color: theme.colorScheme.onSurfaceVariant),
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
