import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/site_data.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/providers/topic_list_provider.dart';
import 'package:lunaris/features/feed/topic_card.dart';

class TopicListView extends ConsumerStatefulWidget {
  final String serverUrl;
  final SiteData siteData;
  final String filter;
  final int? categoryId;
  final String? categorySlug;
  final String? tagName;
  final String? period;
  final ValueChanged<Topic>? onTopicSelected;
  final int? selectedTopicId;

  const TopicListView({
    super.key,
    required this.serverUrl,
    required this.siteData,
    this.filter = 'latest',
    this.categoryId,
    this.categorySlug,
    this.tagName,
    this.period,
    this.onTopicSelected,
    this.selectedTopicId,
  });

  @override
  ConsumerState<TopicListView> createState() => _TopicListViewState();
}

class _TopicListViewState extends ConsumerState<TopicListView> {
  final _scrollController = ScrollController();
  late Map<int, SiteCategory> _categoriesById = {
    for (final cat in widget.siteData.categories) cat.id: cat,
  };

  TopicListParams get _params => TopicListParams(
    serverUrl: widget.serverUrl,
    filter: widget.filter,
    categoryId: widget.categoryId,
    categorySlug: widget.categorySlug,
    tagName: widget.tagName,
    period: widget.period,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant TopicListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteData != widget.siteData) {
      _categoriesById = {
        for (final cat in widget.siteData.categories) cat.id: cat,
      };
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(topicListProvider(_params).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(topicListProvider(_params));
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
              Text('Failed to load topics', style: theme.textTheme.titleMedium),
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
                onPressed:
                    () =>
                        ref.read(topicListProvider(_params).notifier).refresh(),
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
              Icons.forum_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No topics yet',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(topicListProvider(_params).notifier).refresh(),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.topics.length + (state.hasMore ? 1 : 0),
        separatorBuilder:
            (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          if (index == state.topics.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final topic = state.topics[index];
          return TopicCard(
            topic: topic,
            category: _categoriesById[topic.categoryId],
            serverUrl: widget.serverUrl,
            onTap: widget.onTopicSelected != null
                ? () => widget.onTopicSelected!(topic)
                : null,
            selected: widget.selectedTopicId == topic.id,
          );
        },
      ),
    );
  }
}
