import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/models/user_profile.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/providers/user_profile_provider.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/composer/pm_composer_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

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
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _tabCount = 3;

  UserProfileParams get _params => UserProfileParams(
        serverUrl: widget.serverUrl,
        username: widget.username,
      );

  void _ensureTabController(int count) {
    if (_tabController == null || _tabCount != count) {
      _tabController?.dispose();
      _tabCount = count;
      _tabController = TabController(length: count, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
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
    final account = ref.read(activeServerProvider);
    final isOwnProfile = account?.username == profile.username;
    final isStaff = account?.isAdmin == true || account?.isModerator == true;
    final showAdmin = isStaff && !isOwnProfile && profile.hasAdminData;
    final tabCount = showAdmin ? 4 : 3;

    _ensureTabController(tabCount);
    final tabController = _tabController!;

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
              isOwnProfile: isOwnProfile,
              onMessageTap: !isOwnProfile && profile.canSendPrivateMessageToUser
                  ? () => _openMessageComposer(context)
                  : null,
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: tabController,
              tabs: [
                const Tab(text: 'Summary'),
                const Tab(text: 'Activity'),
                const Tab(text: 'Badges'),
                if (showAdmin) const Tab(text: 'Admin'),
              ],
            ),
            theme.colorScheme.surface,
          ),
        ),
      ],
      body: TabBarView(
        controller: tabController,
        children: [
          _SummaryTab(
            profile: profile,
            serverUrl: widget.serverUrl,
            onTopicTap: widget.onTopicTap,
          ),
          _ActivityTab(
            state: state,
            params: _params,
            serverUrl: widget.serverUrl,
            onTopicTap: widget.onTopicTap,
          ),
          _BadgesTab(badges: state.badges),
          if (showAdmin)
            _AdminTab(
              profile: profile,
              params: _params,
            ),
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
  final bool isOwnProfile;
  final VoidCallback? onMessageTap;

  const _ProfileHeader({
    required this.profile,
    required this.serverUrl,
    this.isOwnProfile = false,
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              if (profile.admin)
                const _RoleBadge(label: 'Admin'),
              if (profile.moderator)
                const _RoleBadge(label: 'Moderator'),
              _RoleBadge(label: profile.trustLevelLabel),
              if (onMessageTap != null)
                FilledButton.tonalIcon(
                  onPressed: onMessageTap,
                  icon: const Icon(Icons.mail_rounded, size: 16),
                  label: const Text('Message'),
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
  final String serverUrl;
  final void Function(int topicId)? onTopicTap;

  const _SummaryTab({
    required this.profile,
    required this.serverUrl,
    this.onTopicTap,
  });

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
        if (profile.profileViews != null)
          _InfoRow(
            icon: Icons.visibility_outlined,
            label: '${_formatNumber(profile.profileViews!)} profile views',
          ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Stats'),
        const SizedBox(height: 12),
        _StatsGrid(profile: profile),
        if (profile.topReplies.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Top Replies'),
          const SizedBox(height: 8),
          ...profile.topReplies.take(5).map((r) => _TopicTile(
                title: r.topic?.title ?? 'Untitled',
                subtitle: '${r.likeCount} likes',
                icon: Icons.reply_rounded,
                onTap: r.topic != null ? () => onTopicTap?.call(r.topic!.id) : null,
              )),
        ],
        if (profile.topTopics.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Top Topics'),
          const SizedBox(height: 8),
          ...profile.topTopics.take(5).map((t) => _TopicTile(
                title: t.title,
                subtitle: '${t.likeCount} likes · ${t.postsCount} posts',
                icon: Icons.topic_rounded,
                onTap: () => onTopicTap?.call(t.id),
              )),
        ],
        if (profile.topLinks.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Top Links'),
          const SizedBox(height: 8),
          ...profile.topLinks.take(5).map((l) => _LinkTile(
                title: l.title ?? l.url,
                url: l.url,
                clicks: l.clicks,
              )),
        ],
        if (profile.mostRepliedToUsers.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Most Replied To'),
          const SizedBox(height: 8),
          _UserChipRow(users: profile.mostRepliedToUsers, serverUrl: serverUrl),
        ],
        if (profile.mostLikedByUsers.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Most Liked By'),
          const SizedBox(height: 8),
          _UserChipRow(users: profile.mostLikedByUsers, serverUrl: serverUrl),
        ],
        if (profile.mostLikedUsers.isNotEmpty) ...[
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Most Liked'),
          const SizedBox(height: 8),
          _UserChipRow(users: profile.mostLikedUsers, serverUrl: serverUrl),
        ],
        const SizedBox(height: 32),
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

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}m';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
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
      ('Read Time', -1),
      ('Topics Viewed', profile.topicsEntered),
      ('Posts Read', profile.postsReadCount),
      ('Likes Given', profile.likesGiven),
      ('Likes Received', profile.likesReceived),
      ('Topics Created', profile.topicCreatedCount),
      ('Posts Created', profile.postCount),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map((s) {
        final (label, value) = s;
        final displayValue = label == 'Read Time'
            ? profile.formattedReadTime
            : _formatNumber(value);
        return SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayValue,
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _TopicTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final String url;
  final int clicks;

  const _LinkTile({
    required this.title,
    required this.url,
    required this.clicks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        final uri = Uri.tryParse(url);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$clicks clicks',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserChipRow extends StatelessWidget {
  final List<SummaryUser> users;
  final String serverUrl;

  const _UserChipRow({
    required this.users,
    required this.serverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: users.take(6).map((u) {
        final avatarUrl = u.avatarTemplate != null
            ? resolveAvatarUrl(serverUrl, u.avatarTemplate!, size: 40)
            : null;
        return Tooltip(
          message: u.name ?? u.username,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(u.username[0].toUpperCase(),
                          style: const TextStyle(fontSize: 10))
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  u.username,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${u.count}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
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

class _AdminTab extends ConsumerWidget {
  static const _durations = {
    '1 hour': 1 / 24,
    '3 hours': 3 / 24,
    '1 day': 1.0,
    '3 days': 3.0,
    '1 week': 7.0,
    '2 weeks': 14.0,
    '1 month': 30.0,
    '3 months': 90.0,
    '6 months': 180.0,
    '1 year': 365.0,
    'Forever': 36500.0,
  };

  final UserProfile profile;
  final UserProfileParams params;

  const _AdminTab({required this.profile, required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(userProfileProvider(params).notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.isSuspended) _StatusBanner(
          icon: Icons.block_rounded,
          color: theme.colorScheme.error,
          title: 'Suspended',
          subtitle: profile.suspendReason ?? 'No reason given',
          detail: 'Until ${_formatDateTime(profile.suspendedTill!)}',
        ),
        if (profile.isSilenced) _StatusBanner(
          icon: Icons.volume_off_rounded,
          color: Colors.orange,
          title: 'Silenced',
          subtitle: profile.silenceReason ?? 'No reason given',
          detail: 'Until ${_formatDateTime(profile.silencedTill!)}',
        ),
        if (profile.active == false) _StatusBanner(
          icon: Icons.person_off_rounded,
          color: theme.colorScheme.onSurfaceVariant,
          title: 'Deactivated',
          subtitle: 'Account is not active',
        ),
        if (profile.staged == true) _StatusBanner(
          icon: Icons.schedule_rounded,
          color: theme.colorScheme.onSurfaceVariant,
          title: 'Staged',
          subtitle: 'Account is staged',
        ),

        const _SectionHeader(title: 'User Info'),
        const SizedBox(height: 8),
        _AdminInfoCard(children: [
          if (profile.email != null)
            _AdminInfoRow(icon: Icons.email_outlined, label: 'Email', value: profile.email!),
          _AdminInfoRow(icon: Icons.badge_outlined, label: 'Trust Level',
              value: '${profile.trustLevel} — ${profile.trustLevelLabel}'),
          if (profile.ipAddress != null)
            _AdminInfoRow(icon: Icons.lan_outlined, label: 'IP Address', value: profile.ipAddress!),
          if (profile.registrationIpAddress != null)
            _AdminInfoRow(icon: Icons.how_to_reg_outlined, label: 'Registration IP',
                value: profile.registrationIpAddress!),
          _AdminInfoRow(icon: Icons.flag_outlined, label: 'Flags Received',
              value: '${profile.flagsReceivedCount}'),
          _AdminInfoRow(icon: Icons.outlined_flag_rounded, label: 'Flags Given',
              value: '${profile.flagsGivenCount}'),
          _AdminInfoRow(icon: Icons.warning_amber_rounded, label: 'Warnings',
              value: '${profile.warningsReceivedCount}'),
          if (profile.penaltySuspended != null || profile.penaltySilenced != null)
            _AdminInfoRow(icon: Icons.gavel_rounded, label: 'Penalties',
                value: 'Suspended: ${profile.penaltySuspended ?? 0}, Silenced: ${profile.penaltySilenced ?? 0}'),
          _AdminInfoRow(icon: Icons.lock_outline_rounded, label: 'Private Topics',
              value: '${profile.privateTopicsCount}'),
          if (profile.secondFactorEnabled)
            const _AdminInfoRow(icon: Icons.security_rounded, label: '2FA', value: 'Enabled'),
        ]),

        const SizedBox(height: 24),
        const _SectionHeader(title: 'Actions'),
        const SizedBox(height: 8),

        if (profile.canSuspend) ...[
          if (profile.isSuspended)
            _AdminActionTile(
              icon: Icons.lock_open_rounded,
              label: 'Unsuspend',
              color: Colors.green,
              onTap: () => _confirmAction(context, ref, 'Unsuspend',
                  'Remove suspension from ${profile.username}?',
                  () => notifier.unsuspendUser()),
            )
          else
            _AdminActionTile(
              icon: Icons.block_rounded,
              label: 'Suspend',
              color: theme.colorScheme.error,
              onTap: () => _showSuspendDialog(context, ref, notifier),
            ),
        ],

        if (profile.canSilence) ...[
          if (profile.isSilenced)
            _AdminActionTile(
              icon: Icons.volume_up_rounded,
              label: 'Unsilence',
              color: Colors.green,
              onTap: () => _confirmAction(context, ref, 'Unsilence',
                  'Remove silence from ${profile.username}?',
                  () => notifier.unsilenceUser()),
            )
          else
            _AdminActionTile(
              icon: Icons.volume_off_rounded,
              label: 'Silence',
              color: Colors.orange,
              onTap: () => _showSilenceDialog(context, ref, notifier),
            ),
        ],

        if (profile.canGrantAdmin)
          _AdminActionTile(
            icon: Icons.admin_panel_settings_rounded,
            label: 'Grant Admin',
            onTap: () => _confirmAction(context, ref, 'Grant Admin',
                'Grant admin privileges to ${profile.username}?',
                () => notifier.grantAdmin()),
          ),
        if (profile.canRevokeAdmin)
          _AdminActionTile(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Revoke Admin',
            color: theme.colorScheme.error,
            onTap: () => _confirmAction(context, ref, 'Revoke Admin',
                'Revoke admin privileges from ${profile.username}?',
                () => notifier.revokeAdmin()),
          ),
        if (profile.canGrantModeration)
          _AdminActionTile(
            icon: Icons.shield_rounded,
            label: 'Grant Moderator',
            onTap: () => _confirmAction(context, ref, 'Grant Moderator',
                'Grant moderator privileges to ${profile.username}?',
                () => notifier.grantModeration()),
          ),
        if (profile.canRevokeModeration)
          _AdminActionTile(
            icon: Icons.shield_outlined,
            label: 'Revoke Moderator',
            color: theme.colorScheme.error,
            onTap: () => _confirmAction(context, ref, 'Revoke Moderator',
                'Revoke moderator privileges from ${profile.username}?',
                () => notifier.revokeModeration()),
          ),

        if (profile.canChangeTrustLevel)
          _AdminActionTile(
            icon: Icons.trending_up_rounded,
            label: 'Change Trust Level',
            onTap: () => _showTrustLevelDialog(context, ref, notifier),
          ),

        _AdminActionTile(
          icon: Icons.logout_rounded,
          label: 'Log Out User',
          onTap: () => _confirmAction(context, ref, 'Log Out',
              'Force logout all sessions of ${profile.username}?',
              () => notifier.logOutUser()),
        ),

        if (profile.canActivate)
          _AdminActionTile(
            icon: Icons.check_circle_outline_rounded,
            label: 'Activate',
            color: Colors.green,
            onTap: () => _confirmAction(context, ref, 'Activate',
                'Activate the account of ${profile.username}?',
                () => notifier.activateUser()),
          ),
        if (profile.canDeactivate)
          _AdminActionTile(
            icon: Icons.person_off_outlined,
            label: 'Deactivate',
            color: Colors.orange,
            onTap: () => _confirmAction(context, ref, 'Deactivate',
                'Deactivate the account of ${profile.username}?',
                () => notifier.deactivateUser()),
          ),

        if (profile.canDisableSecondFactor && profile.secondFactorEnabled)
          _AdminActionTile(
            icon: Icons.security_rounded,
            label: 'Disable 2FA',
            color: Colors.orange,
            onTap: () => _confirmAction(context, ref, 'Disable 2FA',
                'Disable two-factor authentication for ${profile.username}?',
                () => notifier.disableSecondFactor()),
          ),

        const SizedBox(height: 24),

        if (profile.canBeAnonymized || profile.canBeDeleted) ...[
          const _SectionHeader(title: 'Danger Zone'),
          const SizedBox(height: 8),
          if (profile.canBeAnonymized)
            _AdminActionTile(
              icon: Icons.person_off_rounded,
              label: 'Anonymize User',
              color: theme.colorScheme.error,
              onTap: () => _confirmAction(context, ref, 'Anonymize',
                  'Anonymize ${profile.username}? This replaces their username and removes personal data. This cannot be undone.',
                  () => notifier.anonymizeUser()),
            ),
          if (profile.canDeleteAllPosts)
            _AdminActionTile(
              icon: Icons.delete_sweep_rounded,
              label: 'Delete All Posts',
              color: theme.colorScheme.error,
              onTap: () => _confirmAction(context, ref, 'Delete Posts',
                  'Delete ALL posts by ${profile.username}? This cannot be undone.',
                  () => notifier.deleteUser(deletePosts: true)),
            ),
          if (profile.canBeDeleted)
            _AdminActionTile(
              icon: Icons.delete_forever_rounded,
              label: 'Delete User',
              color: theme.colorScheme.error,
              onTap: () => _showDeleteDialog(context, ref, notifier),
            ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _confirmAction(
    BuildContext context,
    WidgetRef ref,
    String title,
    String message,
    Future<bool> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(title)),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final success = await action();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? '$title successful' : '$title failed'),
        ));
      }
    }
  }

  Future<void> _showSuspendDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfileNotifier notifier,
  ) async {
    final reasonController = TextEditingController();
    final messageController = TextEditingController();
    String duration = '1 day';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Suspend User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                  items: _durations.keys.map((d) =>
                      DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDialogState(() => duration = v ?? duration),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message to user (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (reasonController.text.isEmpty) return;
                final days = _durations[duration] ?? 1.0;
                final until = DateTime.now().add(Duration(hours: (days * 24).round()));
                Navigator.pop(ctx, {
                  'reason': reasonController.text,
                  'until': until.toIso8601String(),
                  'message': messageController.text,
                });
              },
              child: const Text('Suspend'),
            ),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) {
      final success = await notifier.suspendUser(
        reason: result['reason']!,
        suspendUntil: result['until']!,
        message: result['message']!.isEmpty ? null : result['message'],
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'User suspended' : 'Suspend failed'),
        ));
      }
    }
  }

  Future<void> _showSilenceDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfileNotifier notifier,
  ) async {
    final reasonController = TextEditingController();
    String duration = '1 day';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Silence User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: duration,
                  decoration: const InputDecoration(labelText: 'Duration', border: OutlineInputBorder()),
                  items: _durations.keys.map((d) =>
                      DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDialogState(() => duration = v ?? duration),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (reasonController.text.isEmpty) return;
                final days = _durations[duration] ?? 1.0;
                final until = DateTime.now().add(Duration(hours: (days * 24).round()));
                Navigator.pop(ctx, {
                  'reason': reasonController.text,
                  'until': until.toIso8601String(),
                });
              },
              child: const Text('Silence'),
            ),
          ],
        ),
      ),
    );

    if (result != null && context.mounted) {
      final success = await notifier.silenceUser(
        reason: result['reason']!,
        silencedTill: result['until']!,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'User silenced' : 'Silence failed'),
        ));
      }
    }
  }

  Future<void> _showTrustLevelDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfileNotifier notifier,
  ) async {
    final levels = {0: 'New User', 1: 'Basic User', 2: 'Member', 3: 'Regular', 4: 'Leader'};
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Change Trust Level'),
        children: levels.entries.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, e.key),
          child: Row(
            children: [
              if (e.key == profile.trustLevel)
                const Icon(Icons.check_rounded, size: 20)
              else
                const SizedBox(width: 20),
              const SizedBox(width: 8),
              Text('${e.key} — ${e.value}'),
            ],
          ),
        )).toList(),
      ),
    );

    if (selected != null && selected != profile.trustLevel && context.mounted) {
      final success = await notifier.changeTrustLevel(selected);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? 'Trust level changed to ${levels[selected]}'
              : 'Failed to change trust level'),
        ));
      }
    }
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    UserProfileNotifier notifier,
  ) async {
    bool deletePosts = false;
    bool blockEmail = false;
    bool blockIp = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Delete ${profile.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This action cannot be undone.'),
              const SizedBox(height: 12),
              CheckboxListTile(
                dense: true,
                value: deletePosts,
                onChanged: (v) => setDialogState(() => deletePosts = v ?? false),
                title: const Text('Delete all posts'),
              ),
              CheckboxListTile(
                dense: true,
                value: blockEmail,
                onChanged: (v) => setDialogState(() => blockEmail = v ?? false),
                title: const Text('Block email'),
              ),
              CheckboxListTile(
                dense: true,
                value: blockIp,
                onChanged: (v) => setDialogState(() => blockIp = v ?? false),
                title: const Text('Block IP address'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete User'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await notifier.deleteUser(
        deletePosts: deletePosts,
        blockEmail: blockEmail,
        blockIp: blockIp,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'User deleted' : 'Delete failed'),
        ));
        if (success) Navigator.of(context).pop();
      }
    }
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? detail;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(
                  color: color, fontWeight: FontWeight.w700,
                )),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                )),
                if (detail != null)
                  Text(detail!, style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminInfoCard extends StatelessWidget {
  final List<Widget> children;

  const _AdminInfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, indent: 44, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ],
        ],
      ),
    );
  }
}

class _AdminInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AdminInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ),
          Flexible(
            child: Text(value, style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _AdminActionTile({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = color ?? theme.colorScheme.primary;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: tileColor, size: 22),
      title: Text(label, style: theme.textTheme.bodyMedium?.copyWith(
        color: tileColor,
        fontWeight: FontWeight.w500,
      )),
      trailing: Icon(Icons.chevron_right_rounded, color: tileColor.withValues(alpha: 0.5), size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
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
