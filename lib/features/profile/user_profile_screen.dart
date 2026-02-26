import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/user_profile.dart';
import 'package:lunaris/core/providers/user_profile_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/composer/pm_composer_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserProfileScreen extends ConsumerStatefulWidget {
  final String serverUrl;
  final String username;
  final void Function(int topicId)? onTopicTap;

  const UserProfileScreen({
    super.key,
    required this.serverUrl,
    required this.username,
    this.onTopicTap,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  UserProfileParams get _params => UserProfileParams(
        serverUrl: widget.serverUrl,
        username: widget.username,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProfileProvider(_params));
    final theme = Theme.of(context);

    return Scaffold(
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.profile == null
              ? _buildError(state, theme)
              : state.profile != null
                  ? _buildProfile(state, theme)
                  : const SizedBox.shrink(),
    );
  }

  Widget _buildError(UserProfileState state, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded, size: 48,
                color: theme.colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text('Failed to load profile',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${state.error}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(userProfileProvider(_params).notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfile(UserProfileState state, ThemeData theme) {
    final profile = state.profile!;
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxScrolled) => [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          title: Text(profile.username),
          flexibleSpace: FlexibleSpaceBar(
            background: _ProfileHeader(
              profile: profile,
              serverUrl: widget.serverUrl,
              onMessageTap: profile.canSendPrivateMessageToUser
                  ? () => _openMessageComposer(context)
                  : null,
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'Activity'),
                Tab(text: 'Badges'),
              ],
            ),
            theme.colorScheme.surface,
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(profile: profile),
          _ActivityTab(
            state: state,
            params: _params,
            serverUrl: widget.serverUrl,
            onTopicTap: widget.onTopicTap,
          ),
          _BadgesTab(badges: state.badges),
        ],
      ),
    );
  }

  void _openMessageComposer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PmComposerScreen(serverUrl: widget.serverUrl),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final String serverUrl;
  final VoidCallback? onMessageTap;

  const _ProfileHeader({
    required this.profile,
    required this.serverUrl,
    this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarUrl = profile.avatarTemplate != null
        ? resolveAvatarUrl(serverUrl, profile.avatarTemplate!, size: 120)
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person_rounded, size: 40)
                : null,
          ),
          const SizedBox(height: 12),
          Text(profile.name ?? profile.username,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (profile.name != null && profile.name!.isNotEmpty)
            Text('@${profile.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          if (profile.title != null && profile.title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(profile.title!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  )),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (profile.admin)
                const _RoleBadge(label: 'Admin'),
              if (profile.moderator)
                const _RoleBadge(label: 'Moderator'),
              if (onMessageTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilledButton.tonalIcon(
                    onPressed: onMessageTap,
                    icon: const Icon(Icons.mail_rounded, size: 16),
                    label: const Text('Message'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;

  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _backgroundColor;

  _TabBarDelegate(this._tabBar, this._backgroundColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: _backgroundColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      _tabBar != oldDelegate._tabBar;
}

class _SummaryTab extends StatelessWidget {
  final UserProfile profile;

  const _SummaryTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.bioExcerpt != null && profile.bioExcerpt!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              stripHtml(profile.bioExcerpt!),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (profile.location != null && profile.location!.isNotEmpty)
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: profile.location!,
          ),
        if (profile.websiteName != null && profile.websiteName!.isNotEmpty)
          _InfoRow(
            icon: Icons.language_rounded,
            label: profile.websiteName!,
          ),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Joined ${_formatDate(profile.createdAt)}',
        ),
        if (profile.lastSeenAt != null)
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Last seen ${timeago.format(profile.lastSeenAt!)}',
          ),
        const SizedBox(height: 24),
        Text('Stats', style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        )),
        const SizedBox(height: 12),
        _StatsGrid(profile: profile),
      ],
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final UserProfile profile;

  const _StatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = [
      ('Days Visited', profile.daysVisited),
      ('Posts', profile.postCount),
      ('Topics', profile.topicCount),
      ('Topics Entered', profile.topicsEntered),
      ('Likes Given', profile.likesGiven),
      ('Likes Received', profile.likesReceived),
      ('Posts Read', profile.postsReadCount),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map((s) {
        final (label, value) = s;
        return SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatNumber(value),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  )),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        );
      }).toList(),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _ActivityTab extends ConsumerWidget {
  final UserProfileState state;
  final UserProfileParams params;
  final String serverUrl;
  final void Function(int topicId)? onTopicTap;

  const _ActivityTab({
    required this.state,
    required this.params,
    required this.serverUrl,
    this.onTopicTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activity = state.activity;

    if (activity.isEmpty && !state.isLoadingActivity) {
      return Center(
        child: Text('No recent activity',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent - 200) {
          ref.read(userProfileProvider(params).notifier).loadMoreActivity();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: activity.length + (state.isLoadingActivity ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 56, endIndent: 16),
        itemBuilder: (context, index) {
          if (index == activity.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final action = activity[index];
          return _ActivityTile(
            action: action,
            serverUrl: serverUrl,
            onTap: action.topicId != null
                ? () => onTopicTap?.call(action.topicId!)
                : null,
          );
        },
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final UserAction action;
  final String serverUrl;
  final VoidCallback? onTap;

  const _ActivityTile({
    required this.action,
    required this.serverUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actingAvatar = action.actingAvatarTemplate ?? action.avatarTemplate;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundImage: actingAvatar != null
            ? NetworkImage(resolveAvatarUrl(serverUrl, actingAvatar, size: 36))
            : null,
        child: actingAvatar == null
            ? const Icon(Icons.person_rounded, size: 18)
            : null,
      ),
      title: Text(action.title ?? 'Untitled',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Text(action.actingUsername ?? action.username ?? '',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 4),
          Text(action.actionLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          if (action.createdAt != null) ...[
            const Spacer(),
            Text(timeago.format(action.createdAt!),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _BadgesTab extends StatelessWidget {
  final List<UserBadge> badges;

  const _BadgesTab({required this.badges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (badges.isEmpty) {
      return Center(
        child: Text('No badges yet',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      );
    }

    final grouped = <String, List<UserBadge>>{};
    for (final badge in badges) {
      grouped.putIfAbsent(badge.badgeTypeName, () => []).add(badge);
    }

    final order = ['Gold', 'Silver', 'Bronze'];
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final key in sortedKeys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(key,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _badgeTypeColor(grouped[key]!.first.badgeTypeId),
                )),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: grouped[key]!.map((b) => _BadgeChip(badge: b)).toList(),
          ),
        ],
      ],
    );
  }

  static Color _badgeTypeColor(int typeId) {
    return switch (typeId) {
      1 => const Color(0xFFD4A017),
      2 => const Color(0xFF9E9E9E),
      _ => const Color(0xFFCD7F32),
    };
  }
}

class _BadgeChip extends StatelessWidget {
  final UserBadge badge;

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: stripHtml(badge.description ?? ''),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge.icon != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.emoji_events_rounded, size: 16,
                    color: _BadgesTab._badgeTypeColor(badge.badgeTypeId)),
              ),
            Text(badge.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                )),
            if (badge.grantCount > 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('x${badge.grantCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
          ],
        ),
      ),
    );
  }
}
