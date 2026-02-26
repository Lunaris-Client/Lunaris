import 'package:flutter/material.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/models/site_data.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class CategoryBrowserView extends StatelessWidget {
  final SiteData siteData;
  final ValueChanged<SiteCategory> onCategorySelected;

  const CategoryBrowserView({
    super.key,
    required this.siteData,
    required this.onCategorySelected,
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
      itemCount: hierarchy.length,
      itemBuilder: (context, index) {
        final (category, children) = hierarchy[index];
        return _ParentCategoryTile(
          category: category,
          children: children,
          onCategorySelected: onCategorySelected,
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
  final ValueChanged<SiteCategory> onCategorySelected;

  const _ParentCategoryTile({
    required this.category,
    required this.children,
    required this.onCategorySelected,
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
                  child: Center(child: _categoryIcon(category, theme)),
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
                  ),
              ],
            ),
          ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  static Widget _categoryIcon(SiteCategory category, ThemeData theme) {
    if (category.emoji != null) {
      return Text(category.emoji!, style: const TextStyle(fontSize: 18));
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

  const _ChildCategoryTile({
    required this.category,
    required this.onCategorySelected,
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
