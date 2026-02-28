import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/models/site_data.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class CategoryBrowserView extends StatelessWidget {
  final SiteData siteData;
  final String serverUrl;
  final ValueChanged<SiteCategory> onCategorySelected;
  final VoidCallback? onAllTopicsTap;
  final Map<int, int> unreadCounts;

  const CategoryBrowserView({
    super.key,
    required this.siteData,
    required this.serverUrl,
    required this.onCategorySelected,
    this.onAllTopicsTap,
    this.unreadCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final hierarchy = _buildHierarchy(siteData.categories);

    if (hierarchy.isEmpty) {
      final theme = Theme.of(context);
      return Center(
        child: Text(
          'No categories',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: hierarchy.length + (onAllTopicsTap != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (onAllTopicsTap != null && index == 0) {
          return _AllTopicsItem(onTap: onAllTopicsTap!);
        }
        final adjustedIndex = onAllTopicsTap != null ? index - 1 : index;
        final (category, children) = hierarchy[adjustedIndex];
        return _ParentCategoryTile(
          category: category,
          children: children,
          serverUrl: serverUrl,
          onCategorySelected: onCategorySelected,
          unreadCounts: unreadCounts,
        );
      },
    );
  }

  List<(SiteCategory, List<SiteCategory>)> _buildHierarchy(
    List<SiteCategory> cats,
  ) {
    final topLevel =
        cats.where((c) => c.parentCategoryId == null).toList()
          ..sort((a, b) => (a.position ?? 999).compareTo(b.position ?? 999));

    final childMap = <int, List<SiteCategory>>{};
    for (final cat in cats) {
      if (cat.parentCategoryId != null) {
        childMap.putIfAbsent(cat.parentCategoryId!, () => []).add(cat);
      }
    }
    for (final children in childMap.values) {
      children.sort((a, b) => (a.position ?? 999).compareTo(b.position ?? 999));
    }

    return [
      for (final parent in topLevel)
        (parent, childMap[parent.id] ?? <SiteCategory>[]),
    ];
  }
}

class _ParentCategoryTile extends StatelessWidget {
  final SiteCategory category;
  final List<SiteCategory> children;
  final String serverUrl;
  final ValueChanged<SiteCategory> onCategorySelected;
  final Map<int, int> unreadCounts;

  const _ParentCategoryTile({
    required this.category,
    required this.children,
    required this.serverUrl,
    required this.onCategorySelected,
    this.unreadCounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(category.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => onCategorySelected(category),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _categoryImage(category, serverUrl, theme),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: theme.textTheme.titleSmall),
                      if (category.descriptionExcerpt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            stripHtml(category.descriptionExcerpt!),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if ((unreadCounts[category.id] ?? 0) > 0)
                  _UnreadBadge(count: unreadCounts[category.id]!),
                if ((unreadCounts[category.id] ?? 0) > 0)
                  const SizedBox(width: 6),
                _TopicCountBadge(count: category.topicCount),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              children: [
                for (final child in children)
                  _ChildCategoryTile(
                    category: child,
                    onCategorySelected: onCategorySelected,
                    unreadCount: unreadCounts[child.id] ?? 0,
                  ),
              ],
            ),
          ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  static Widget _categoryImage(
    SiteCategory category,
    String serverUrl,
    ThemeData theme,
  ) {
    final logoUrl = category.uploadedLogoUrl ?? category.uploadedLogoDarkUrl;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      final resolved =
          logoUrl.startsWith('http') ? logoUrl : '$serverUrl$logoUrl';
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CachedNetworkImage(
          imageUrl: resolved,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorWidget: (_, __, ___) =>
              _categoryFallbackIcon(category, serverUrl),
        ),
      );
    }
    return _categoryFallbackIcon(category, serverUrl);
  }

  static Widget _categoryFallbackIcon(
    SiteCategory category,
    String serverUrl,
  ) {
    if (category.emoji != null && category.emoji!.isNotEmpty) {
      final shortcode = category.emoji!.replaceAll(':', '');
      return CachedNetworkImage(
        imageUrl: '$serverUrl/images/emoji/twitter/$shortcode.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => Text(
          category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }
    if (category.icon != null) {
      return const Icon(Icons.folder_rounded, size: 18, color: Colors.white);
    }
    return Text(
      category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}

class _ChildCategoryTile extends StatelessWidget {
  final SiteCategory category;
  final ValueChanged<SiteCategory> onCategorySelected;
  final int unreadCount;

  const _ChildCategoryTile({
    required this.category,
    required this.onCategorySelected,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = parseHexColor(category.color);

    return InkWell(
      onTap: () => onCategorySelected(category),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(category.name, style: theme.textTheme.bodyMedium),
            ),
            if (unreadCount > 0) ...[          
              _UnreadBadge(count: unreadCount),
              const SizedBox(width: 6),
            ],
            _TopicCountBadge(count: category.topicCount),
          ],
        ),
      ),
    );
  }
}

class _TopicCountBadge extends StatelessWidget {
  final int count;

  const _TopicCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formatCount(count),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formatCount(count),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AllTopicsItem extends StatelessWidget {
  final VoidCallback onTap;

  const _AllTopicsItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.forum_rounded, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All Topics',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
