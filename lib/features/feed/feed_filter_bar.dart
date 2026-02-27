import 'package:flutter/material.dart';

class FeedFilterBar extends StatelessWidget {
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;
  final String? activePeriod;
  final ValueChanged<String> onPeriodChanged;
  final List<String> periods;

  const FeedFilterBar({
    super.key,
    required this.activeFilter,
    required this.onFilterChanged,
    this.activePeriod,
    required this.onPeriodChanged,
    required this.periods,
  });

  static const _filters = <(String, String)>[
    ('latest', 'Latest'),
    ('new', 'New'),
    ('unread', 'Unread'),
    ('top', 'Top'),
    ('hot', 'Hot'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showPeriods = activeFilter == 'top' && periods.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final (key, label) = _filters[index];
              final selected = activeFilter == key;
              return Center(
                child: Material(
                  color: selected
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => onFilterChanged(key),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (showPeriods)
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: periods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 2),
              itemBuilder: (context, index) {
                final period = periods[index];
                final selected = activePeriod == period;
                return Center(
                  child: Material(
                    color: selected
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onPeriodChanged(period),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(
                          _periodLabel(period),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  static String _periodLabel(String period) {
    return switch (period) {
      'daily' => 'Day',
      'weekly' => 'Week',
      'monthly' => 'Month',
      'quarterly' => 'Quarter',
      'yearly' => 'Year',
      'all' => 'All',
      _ => period[0].toUpperCase() + period.substring(1),
    };
  }
}
