import 'package:flutter/material.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class CategoryFilterSheet extends StatelessWidget {
  final List<SiteCategory> categories;
  final SiteCategory? selected;

  const CategoryFilterSheet({
    super.key,
    required this.categories,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = _buildHierarchy(categories);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Filter by Category',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (selected != null)
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'clear'),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final (category, depth) = sorted[index];
                  final isSelected = selected?.id == category.id;

                  return ListTile(
                    selected: isSelected,
                    contentPadding: EdgeInsets.only(
                      left: 16.0 + (depth * 24.0),
                      right: 16,
                    ),
                    leading: CircleAvatar(
                      radius: 8,
                      backgroundColor: parseHexColor(category.color),
                    ),
                    title: Text(category.name),
                    subtitle:
                        category.descriptionExcerpt != null
                            ? Text(
                              category.descriptionExcerpt!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                            : null,
                    trailing:
                        isSelected
                            ? Icon(
                              Icons.check_rounded,
                              color: theme.colorScheme.primary,
                            )
                            : null,
                    onTap: () => Navigator.pop(context, category),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<(SiteCategory, int)> _buildHierarchy(List<SiteCategory> cats) {
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

    final result = <(SiteCategory, int)>[];
    for (final parent in topLevel) {
      result.add((parent, 0));
      for (final child in childMap[parent.id] ?? []) {
        result.add((child, 1));
      }
    }
    return result;
  }
}
