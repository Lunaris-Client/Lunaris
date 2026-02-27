import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final SiteCategory? category;
  final String serverUrl;
  final VoidCallback? onTap;
  final bool selected;

  const TopicCard({
    super.key,
    required this.topic,
    this.category,
    required this.serverUrl,
    this.onTap,
    this.selected = false,
  });

  bool get _hasUnread =>
      topic.lastReadPostNumber != null &&
      topic.lastReadPostNumber! < topic.highestPostNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitle(theme),
              const SizedBox(height: 6),
              if (topic.excerpt != null && topic.excerpt!.isNotEmpty) ...[
                _buildExcerpt(theme),
                const SizedBox(height: 8),
              ],
              _buildMeta(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasUnread)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        Expanded(
          child: Text(
            topic.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: _hasUnread ? FontWeight.w600 : FontWeight.w500,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (topic.pinned)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Icon(
              Icons.push_pin_rounded,
              size: 14,
              color: theme.colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }

  Widget _buildExcerpt(ThemeData theme) {
    final cleaned = stripHtml(topic.excerpt!);
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Text(
      cleaned,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        height: 1.4,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildMeta(ThemeData theme) {
    final metaStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
    );

    final parts = <String>[];
    if (category != null) parts.add(category!.name);
    parts.add(timeago.format(topic.bumpedAt, locale: 'en_short'));
    if (topic.replyCount > 0) parts.add('${formatCount(topic.replyCount)} replies');
    if (topic.likeCount > 0) parts.add('${formatCount(topic.likeCount)} likes');
    if (topic.hasAcceptedAnswer) parts.add('solved');
    if (topic.closed && !topic.archived) parts.add('closed');

    return Row(
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
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text(
            category != null ? parts.skip(1).join(' · ') : parts.join(' · '),
            style: metaStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (topic.tags.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            topic.tags.take(2).map((t) => t.name).join(', '),
            style: metaStyle?.copyWith(fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
