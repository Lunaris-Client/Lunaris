import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class TopicCard extends StatelessWidget {
  final Topic topic;
  final SiteCategory? category;
  final String serverUrl;
  final VoidCallback? onTap;

  const TopicCard({
    super.key,
    required this.topic,
    this.category,
    required this.serverUrl,
    this.onTap,
  });

  bool get _hasUnread =>
      topic.lastReadPostNumber != null &&
      topic.lastReadPostNumber! < topic.highestPostNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 6),
            _buildTitle(theme),
            if (topic.excerpt != null && topic.excerpt!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildExcerpt(theme),
            ],
            if (topic.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildTags(theme),
            ],
            const SizedBox(height: 10),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        if (category != null) ...[
          _CategoryBadge(category: category!),
          const SizedBox(width: 8),
        ],
        if (topic.pinned) ...[
          Icon(
            Icons.push_pin_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
        ],
        if (topic.closed) ...[
          Icon(
            Icons.lock_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
        ],
        if (topic.archived) ...[
          Icon(
            Icons.inventory_2_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
        ],
        const Spacer(),
        Text(
          timeago.format(topic.bumpedAt),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        Expanded(
          child: Text(
            topic.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: _hasUnread ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildExcerpt(ThemeData theme) {
    final cleaned =
        topic.excerpt!
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&hellip;', '...')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .trim();
    if (cleaned.isEmpty) return const SizedBox.shrink();

    return Text(
      cleaned,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTags(ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children:
          topic.tags.take(5).map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tag.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final posterAvatars =
        topic.posters.where((p) => p.user != null).take(5).toList();

    return Row(
      children: [
        if (posterAvatars.isNotEmpty) ...[
          _AvatarRow(posters: posterAvatars, serverUrl: serverUrl),
          const SizedBox(width: 12),
        ],
        _StatChip(
          icon: Icons.chat_bubble_outline_rounded,
          value: topic.replyCount,
        ),
        const SizedBox(width: 12),
        _StatChip(icon: Icons.visibility_outlined, value: topic.views),
        if (topic.likeCount > 0) ...[
          const SizedBox(width: 12),
          _StatChip(
            icon: Icons.favorite_border_rounded,
            value: topic.likeCount,
          ),
        ],
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final SiteCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(category.color);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          category.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AvatarRow extends StatelessWidget {
  final List<TopicPoster> posters;
  final String serverUrl;

  const _AvatarRow({required this.posters, required this.serverUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            posters.map((poster) {
              final template = poster.user!.avatarTemplate;
              final url =
                  template.startsWith('http')
                      ? template.replaceAll('{size}', '48')
                      : '$serverUrl${template.replaceAll('{size}', '48')}';

              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: CircleAvatar(
                  radius: 12,
                  backgroundImage: CachedNetworkImageProvider(url),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int value;

  const _StatChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          _formatCount(value),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static String _formatCount(int count) {
    if (count >= 10000) return '${(count / 1000).toStringAsFixed(0)}k';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
