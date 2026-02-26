import 'package:flutter/material.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/utils/color_utils.dart';

class FeedFilterBar extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;
  final String? activePeriod;
  final ValueChanged<String> onPeriodChanged;
  final List<String> periods;
  final SiteCategory? activeCategory;
  final VoidCallback onCategoryTap;
  final VoidCallback? onCategoryClear;
  final String? activeTag;
  final VoidCallback onTagTap;
  final VoidCallback? onTagClear;

  const FeedFilterBar({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
    this.activePeriod,
    required this.onPeriodChanged,
    required this.periods,
    this.activeCategory,
    required this.onCategoryTap,
    this.onCategoryClear,
    this.activeTag,
    required this.onTagTap,
    this.onTagClear,
  });

  static const _filters = <(String, String, IconData)>[
    ('latest', 'Latest', Icons.schedule_rounded),
    ('new', 'New', Icons.fiber_new_rounded),
    ('unread', 'Unread', Icons.mark_email_unread_rounded),
    ('top', 'Top', Icons.trending_up_rounded),
    ('hot', 'Hot', Icons.local_fire_department_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              for (final (key, label, icon) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: activeFilter == key,
                    label: Text(label),
                    avatar: Icon(icon, size: 16),
                    onSelected: (_) => onFilterChanged(key),
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(width: 4),
              _buildCategoryChip(theme),
              const SizedBox(width: 6),
              _buildTagChip(theme),
            ],
          ),
        ),
        if (activeFilter == 'top' && periods.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: Row(
              children: [
                for (final period in periods)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      selected: activePeriod == period,
                      label: Text(_periodLabel(period)),
                      onSelected: (_) => onPeriodChanged(period),
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      labelStyle: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildCategoryChip(ThemeData theme) {
    if (activeCategory != null) {
      return InputChip(
        label: Text(activeCategory!.name),
        avatar: CircleAvatar(
          radius: 7,
          backgroundColor: parseHexColor(activeCategory!.color),
        ),
        onDeleted: onCategoryClear,
        onPressed: onCategoryTap,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }
    return ActionChip(
      label: const Text('Category'),
      avatar: Icon(
        Icons.category_rounded,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: onCategoryTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTagChip(ThemeData theme) {
    if (activeTag != null) {
      return InputChip(
        label: Text(activeTag!),
        avatar: const Icon(Icons.tag_rounded, size: 16),
        onDeleted: onTagClear,
        onPressed: onTagTap,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }
    return ActionChip(
      label: const Text('Tag'),
      avatar: Icon(
        Icons.tag_rounded,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onPressed: onTagTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  static String _periodLabel(String period) {
    return switch (period) {
      'daily' => 'Day',
      'weekly' => 'Week',
      'monthly' => 'Month',
      'quarterly' => 'Quarter',
      'yearly' => 'Year',
      'all' => 'All Time',
      _ => period[0].toUpperCase() + period.substring(1),
    };
  }
}
