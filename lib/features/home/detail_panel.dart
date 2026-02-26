import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class DetailPanel extends StatelessWidget {
  final Topic? selectedTopic;
  final SiteCategory? category;

  const DetailPanel({
    super.key,
    this.selectedTopic,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedTopic == null) return _buildEmptyState(context);
    return _buildTopicPreview(context, selectedTopic!);
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a topic to read',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicPreview(BuildContext context, Topic topic) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category != null) ...[
            _buildCategoryRow(theme),
            const SizedBox(height: 12),
          ],
          Text(
            topic.title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildMeta(theme, topic),
          if (topic.excerpt != null && topic.excerpt!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              stripHtml(topic.excerpt!),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          if (topic.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topic.tags.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag.name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(ThemeData theme) {
    final color = parseHexColor(category!.color);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          category!.name,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMeta(ThemeData theme, Topic topic) {
    final items = <String>[
      '${topic.replyCount} ${topic.replyCount == 1 ? 'reply' : 'replies'}',
      '${formatCount(topic.views)} views',
      if (topic.likeCount > 0) '${formatCount(topic.likeCount)} likes',
      timeago.format(topic.bumpedAt),
    ];

    return Text(
      items.join(' \u00b7 '),
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
