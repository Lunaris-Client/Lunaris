import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/reviewable.dart';
import 'package:lunaris/core/providers/admin_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:timeago/timeago.dart' as timeago;

class ReviewQueueView extends ConsumerWidget {
  final String serverUrl;

  const ReviewQueueView({super.key, required this.serverUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ReviewQueueParams(serverUrl: serverUrl);
    final state = ref.watch(reviewQueueProvider(params));
    final notifier = ref.read(reviewQueueProvider(params).notifier);
    final theme = Theme.of(context);

    return Column(
      children: [
        _FilterBar(
          selected: state.statusFilter,
          onChanged: notifier.setFilter,
        ),
        Expanded(
          child: _buildBody(state, notifier, theme),
        ),
      ],
    );
  }

  Widget _buildBody(
    ReviewQueueState state,
    ReviewQueueNotifier notifier,
    ThemeData theme,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48,
                color: theme.colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('Failed to load review queue',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => notifier.refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('Review queue is empty', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
            notifier.loadMore();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.items.length + (state.isLoading ? 1 : 0),
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _ReviewableCard(
              reviewable: state.items[index],
              serverUrl: serverUrl,
              onAction: (actionId) {
                final item = state.items[index];
                notifier.performAction(item.id, actionId, item.version);
              },
            );
          },
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  static const _filters = [
    ('pending', 'Pending'),
    ('approved', 'Approved'),
    ('rejected', 'Rejected'),
    ('deleted', 'Deleted'),
    ('ignored', 'Ignored'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((f) {
          final isSelected = f.$1 == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(f.$2),
              selected: isSelected,
              onSelected: (_) => onChanged(f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReviewableCard extends StatelessWidget {
  final Reviewable reviewable;
  final String serverUrl;
  final ValueChanged<String> onAction;

  const _ReviewableCard({
    required this.reviewable,
    required this.serverUrl,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTypeChip(theme),
              const Spacer(),
              Text(
                timeago.format(reviewable.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (reviewable.createdBy != null) _buildUserRow(theme),
          if (reviewable.cookedContent != null &&
              reviewable.cookedContent!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _stripHtml(reviewable.cookedContent!),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          if (reviewable.score > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flag_rounded, size: 14,
                    color: theme.colorScheme.error),
                const SizedBox(width: 4),
                Text(
                  'Score: ${reviewable.score.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
          if (reviewable.actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reviewable.actions.map((action) {
                return _buildActionButton(theme, action);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeChip(ThemeData theme) {
    final color = switch (reviewable.typeLabel) {
      'Flagged Post' => theme.colorScheme.error,
      'Queued Post' => theme.colorScheme.tertiary,
      'User' => theme.colorScheme.primary,
      _ => theme.colorScheme.secondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        reviewable.typeLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildUserRow(ThemeData theme) {
    final user = reviewable.createdBy!;
    return Row(
      children: [
        if (user.avatarTemplate != null)
          CircleAvatar(
            radius: 12,
            backgroundImage: NetworkImage(
              resolveAvatarUrl(serverUrl, user.avatarTemplate!, size: 40),
            ),
          )
        else
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.person, size: 12,
                color: theme.colorScheme.onPrimaryContainer),
          ),
        const SizedBox(width: 8),
        Text(
          user.username,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(ThemeData theme, ReviewableAction action) {
    final isDestructive = action.id.contains('delete') ||
        action.id.contains('reject') ||
        action.id.contains('disagree');
    final isPositive = !isDestructive &&
        (action.id.contains('approve') || action.id.contains('agree'));

    final Color buttonColor;
    if (isDestructive) {
      buttonColor = theme.colorScheme.error;
    } else if (isPositive) {
      buttonColor = theme.colorScheme.primary;
    } else {
      buttonColor = theme.colorScheme.onSurfaceVariant;
    }

    final displayLabel = action.label ?? action.id;

    if (isPositive) {
      return FilledButton.tonal(
        onPressed: () => onAction(action.id),
        child: Text(displayLabel),
      );
    }

    return OutlinedButton(
      onPressed: () => onAction(action.id),
      style: OutlinedButton.styleFrom(
        foregroundColor: buttonColor,
      ),
      child: Text(displayLabel),
    );
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
