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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (key, label, icon) in _filters)
                ChoiceChip(
                  selected: activeFilter == key,
                  label: Text(label),
                  avatar: Icon(icon, size: 16),
                  onSelected: (_) => onFilterChanged(key),
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        if (activeFilter == 'top' && periods.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final period in periods)
                  ChoiceChip(
                    selected: activePeriod == period,
                    label: Text(_periodLabel(period)),
                    onSelected: (_) => onPeriodChanged(period),
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    labelStyle: theme.textTheme.labelSmall,
                  ),
              ],
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
      'all' => 'All Time',
      _ => period[0].toUpperCase() + period.substring(1),
    };
  }
}
