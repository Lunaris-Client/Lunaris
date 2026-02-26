import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/app/router.dart';
import 'package:lunaris/core/layout/breakpoints.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/models/site_data.dart';
import 'package:lunaris/core/models/topic.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/core/utils/color_utils.dart';
import 'package:lunaris/features/categories/category_browser_view.dart';
import 'package:lunaris/features/feed/feed_filter_bar.dart';
import 'package:lunaris/features/feed/topic_list_view.dart';
import 'package:lunaris/features/home/detail_panel.dart';
import 'package:lunaris/features/home/server_switcher_drawer.dart';
import 'package:lunaris/features/home/sidebar_navigation.dart';
import 'package:lunaris/core/providers/message_bus_provider.dart';
import 'package:lunaris/core/providers/notification_provider.dart';
import 'package:lunaris/core/providers/notification_settings_provider.dart';
import 'package:lunaris/core/services/local_notification_service.dart';
import 'package:lunaris/features/bookmarks/bookmark_list_view.dart';
import 'package:lunaris/features/composer/new_topic_composer_screen.dart';
import 'package:lunaris/features/composer/pm_composer_screen.dart';
import 'package:lunaris/features/messages/pm_inbox_view.dart';
import 'package:lunaris/features/notifications/notification_list_view.dart';
import 'package:lunaris/features/search/search_screen.dart';
import 'package:lunaris/features/topic/topic_view_screen.dart';
import 'package:lunaris/core/providers/connectivity_provider.dart';
import 'package:lunaris/core/services/offline_action_service.dart';
import 'package:lunaris/core/services/app_badge_service.dart';
import 'package:lunaris/core/services/haptic_service.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentTab = 0;
  String _activeFilter = 'latest';
  SiteCategory? _selectedCategory;
  String _selectedPeriod = 'all';
  Topic? _selectedTopic;
  String? _connectedServerUrl;

  @override
  void dispose() {
    ref.read(messageBusProvider.notifier).disconnect();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (index == _currentTab) return;
    HapticService.selection();
    setState(() {
      _currentTab = index;
      _selectedTopic = null;
    });
  }

  void _onFilterChanged(String filter) {
    if (filter == _activeFilter) return;
    setState(() {
      _activeFilter = filter;
      _selectedTopic = null;
    });
  }

  void _onPeriodChanged(String period) {
    if (period == _selectedPeriod) return;
    setState(() {
      _selectedPeriod = period;
      _selectedTopic = null;
    });
  }

  void _onTopicSelected(Topic topic) {
    final breakpoint = layoutBreakpointOf(MediaQuery.sizeOf(context).width);
    if (breakpoint == LayoutBreakpoint.mobile) {
      final server = ref.read(activeServerProvider);
      if (server == null) return;
      final siteAsync = ref.read(siteDataProvider(server.serverUrl));
      final categoriesById =
          siteAsync.valueOrNull != null
              ? {for (final c in siteAsync.valueOrNull!.categories) c.id: c}
              : null;
      context.push(
        '/topic/${topic.id}',
        extra: TopicRouteExtra(
          serverUrl: server.serverUrl,
          topicTitle: topic.title,
          categoriesById: categoriesById,
        ),
      );
    } else {
      setState(() => _selectedTopic = topic);
    }
  }

  void _onCategoryBrowseSelected(SiteCategory category) {
    setState(() {
      _selectedCategory = category;
      _activeFilter = 'latest';
      _selectedTopic = null;
      _currentTab = 0;
    });
  }

  void _openNewMessageComposer() {
    final server = ref.read(activeServerProvider);
    if (server == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PmComposerScreen(serverUrl: server.serverUrl),
      ),
    );
  }

  void _openNewTopicComposer(SiteData siteData) {
    final server = ref.read(activeServerProvider);
    if (server == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => NewTopicComposerScreen(
              serverUrl: server.serverUrl,
              categories: siteData.categories,
              topTags: siteData.topTags,
              canTagTopics: siteData.canTagTopics,
              canCreateTag: siteData.canCreateTag,
            ),
      ),
    );
  }

  void _openSearch(ServerAccount server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          serverUrl: server.serverUrl,
          onTopicTap: (topicId) {
            Navigator.of(context).pop();
            _navigateToTopic(server, topicId);
          },
          onUserTap: (username) {
            Navigator.of(context).pop();
            _openUserProfile(server, username);
          },
        ),
      ),
    );
  }

  void _openUserProfile(ServerAccount server, String username) {
    context.push(
      '/user/$username',
      extra: UserProfileRouteExtra(serverUrl: server.serverUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    final theme = Theme.of(context);
    final breakpoint = layoutBreakpointOf(MediaQuery.sizeOf(context).width);

    if (server == null || !server.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_connectedServerUrl != server.serverUrl) {
      _connectedServerUrl = server.serverUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(messageBusProvider.notifier).connect(server);
      });
    }

    ref.listen<MessageBusEvent?>(messageBusProvider, (prev, next) {
      if (next == null || !mounted) return;
      if (next.type == 'notification_alert' && next.data is Map) {
        final data = next.data as Map;
        final notificationType = data['notification_type'] as int? ?? 0;
        final settings = ref.read(
          notificationSettingsProvider(server.serverUrl),
        );

        if (!settings.shouldNotify(notificationType)) return;

        final excerpt =
            data['excerpt'] as String? ??
            data['fancy_title'] as String? ??
            'New notification';
        final username = data['username'] as String? ?? '';
        final displayText =
            username.isNotEmpty ? '$username: $excerpt' : excerpt;

        if (settings.showInAppToasts) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  displayText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () {
                    setState(() => _currentTab = 2);
                  },
                ),
              ),
            );
        }

        if (settings.showSystemNotifications) {
          LocalNotificationService().show(
            id: notificationType + DateTime.now().millisecond,
            title: server.siteName,
            body: displayText,
            payload: server.serverUrl,
          );
        }
      }
    });

    final siteAsync = ref.watch(siteDataProvider(server.serverUrl));

    ref.listen(siteDataProvider(server.serverUrl), (prev, next) {
      if (next.hasValue && next.value != null) {
        final service = ref.read(siteBootstrapServiceProvider);
        if (service.needsRefresh(next.value!)) {
          ref.read(siteDataProvider(server.serverUrl).notifier).refresh();
        }
      }
    });

    ref.listen(notificationListProvider(server.serverUrl), (prev, next) {
      AppBadgeService.updateCount(next.unreadCount);
    });

    final avatarUrl =
        server.avatarTemplate != null
            ? resolveAvatarUrl(
              server.serverUrl,
              server.avatarTemplate!,
              size: 40,
            )
            : null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: breakpoint == LayoutBreakpoint.mobile,
        title: Text(server.siteName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => _openSearch(server),
          ),
          if (_currentTab == 2) _buildMarkAllReadButton(server.serverUrl),
          if (breakpoint == LayoutBreakpoint.mobile)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: server.username != null && server.username!.isNotEmpty
                    ? () => _openUserProfile(server, server.username!)
                    : null,
                child: avatarUrl != null
                      ? CircleAvatar(
                        radius: 16,
                        backgroundImage: CachedNetworkImageProvider(avatarUrl),
                      )
                      : CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Builder(
                builder: (scaffoldContext) => GestureDetector(
                  onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                  child: _buildSiteLogo(server, theme),
                ),
              ),
            ),
        ],
      ),
      drawer: const ServerSwitcherDrawer(),
      floatingActionButton:
          _currentTab == 0 && _selectedTopic == null
              ? siteAsync.whenOrNull(
                data: (siteData) {
                  if (siteData == null) return null;
                  return FloatingActionButton(
                    heroTag: 'fab_new_topic',
                    onPressed: () => _openNewTopicComposer(siteData),
                    child: const Icon(Icons.add_rounded),
                  );
                },
              )
              : _currentTab == 4
                  ? FloatingActionButton(
                      heroTag: 'fab_new_message',
                      onPressed: _openNewMessageComposer,
                      child: const Icon(Icons.edit_rounded),
                    )
                  : null,
      body: Column(
        children: [
          const _OfflineBanner(),
          Expanded(
            child: siteAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (error, _) => _BootstrapError(
                    error: error,
                    onRetry:
                        () =>
                            ref
                                .read(siteDataProvider(server.serverUrl).notifier)
                                .refresh(),
                  ),
              data: (siteData) {
                if (siteData == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildResponsiveBody(breakpoint, siteData, server);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          breakpoint == LayoutBreakpoint.mobile
              ? NavigationBar(
                selectedIndex: _currentTab,
                onDestinationSelected: _onTabChanged,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.forum_outlined),
                    selectedIcon: Icon(Icons.forum_rounded),
                    label: 'Feed',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.category_outlined),
                    selectedIcon: Icon(Icons.category_rounded),
                    label: 'Categories',
                  ),
                  NavigationDestination(
                    icon: _NotificationBadge(
                      serverUrl: server.serverUrl,
                      icon: Icons.notifications_outlined,
                    ),
                    selectedIcon: _NotificationBadge(
                      serverUrl: server.serverUrl,
                      icon: Icons.notifications_rounded,
                    ),
                    label: 'Notifications',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.bookmark_outline_rounded),
                    selectedIcon: Icon(Icons.bookmark_rounded),
                    label: 'Bookmarks',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.mail_outlined),
                    selectedIcon: Icon(Icons.mail_rounded),
                    label: 'Messages',
                  ),
                ],
              )
              : null,
    );
  }

  Widget _buildResponsiveBody(
    LayoutBreakpoint breakpoint,
    SiteData siteData,
    ServerAccount server,
  ) {
    final Widget content;
    switch (_currentTab) {
      case 1:
        content = CategoryBrowserView(
          siteData: siteData,
          onCategorySelected: _onCategoryBrowseSelected,
        );
      case 2:
        content = _buildNotificationsTab(server);
      case 3:
        content = _buildBookmarksTab(server);
      case 4:
        content = _buildMessagesTab(server);
      default:
        content = _buildFeedTab(siteData, server.serverUrl);
    }

    if (breakpoint == LayoutBreakpoint.mobile) return content;

    final categoriesById = {for (final c in siteData.categories) c.id: c};

    final unreadCount =
        ref.watch(notificationListProvider(server.serverUrl)).unreadCount;

    return Row(
      children: [
        SidebarNavigation(
          selectedIndex: _currentTab,
          onDestinationSelected: _onTabChanged,
          extended: breakpoint == LayoutBreakpoint.desktop,
          activeServer: breakpoint == LayoutBreakpoint.desktop ? server : null,
          notificationBadgeCount: unreadCount,
          onAvatarTap: server.username != null && server.username!.isNotEmpty
              ? () => _openUserProfile(server, server.username!)
              : null,
        ),
        const VerticalDivider(width: 1),
        Expanded(flex: 2, child: content),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child:
              _selectedTopic != null
                  ? TopicViewScreen(
                    key: ValueKey(_selectedTopic!.id),
                    serverUrl: server.serverUrl,
                    topicId: _selectedTopic!.id,
                    topicTitle: _selectedTopic!.title,
                    categoriesById: categoriesById,
                    embedded: true,
                  )
                  : const DetailPanel(),
        ),
      ],
    );
  }

  Widget _buildFeedTab(SiteData siteData, String serverUrl) {
    final effectivePeriod = _activeFilter == 'top' ? _selectedPeriod : null;
    return Column(
      children: [
        FeedFilterBar(
          activeFilter: _activeFilter,
          onFilterChanged: _onFilterChanged,
          activePeriod: _selectedPeriod,
          onPeriodChanged: _onPeriodChanged,
          periods: siteData.periods,
        ),
        Expanded(
          child: TopicListView(
            key: ValueKey(
              '$_activeFilter-${_selectedCategory?.id}-$effectivePeriod',
            ),
            serverUrl: serverUrl,
            siteData: siteData,
            filter: _activeFilter,
            categoryId: _selectedCategory?.id,
            categorySlug: _selectedCategory?.slug,
            period: effectivePeriod,
            onTopicSelected: _onTopicSelected,
            selectedTopicId: _selectedTopic?.id,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsTab(ServerAccount server) {
    return NotificationListView(
      serverUrl: server.serverUrl,
      onNotificationTap: (topicId, postNumber) {
        _navigateToTopic(server, topicId);
      },
    );
  }

  Widget _buildBookmarksTab(ServerAccount server) {
    final username = server.username;
    if (username == null || username.isEmpty) {
      return const Center(child: Text('Username not available'));
    }
    return BookmarkListView(
      serverUrl: server.serverUrl,
      username: username,
    );
  }

  Widget _buildMessagesTab(ServerAccount server) {
    final username = server.username;
    if (username == null || username.isEmpty) {
      return const Center(child: Text('Username not available'));
    }
    return PmInboxView(
      serverUrl: server.serverUrl,
      username: username,
      onTopicSelected: _onTopicSelected,
      selectedTopicId: _selectedTopic?.id,
    );
  }

  Widget _buildMarkAllReadButton(String serverUrl) {
    final state = ref.watch(notificationListProvider(serverUrl));
    final notifier = ref.read(notificationListProvider(serverUrl).notifier);
    if (state.unreadCount == 0) return const SizedBox.shrink();
    if (state.isMarkingRead) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.done_all_rounded),
      tooltip: 'Mark all read',
      onPressed: () => notifier.markAllRead(),
    );
  }

  void _navigateToTopic(ServerAccount server, int topicId) {
    final siteAsync = ref.read(siteDataProvider(server.serverUrl));
    final categoriesById =
        siteAsync.valueOrNull != null
            ? {for (final c in siteAsync.valueOrNull!.categories) c.id: c}
            : null;

    context.push(
      '/topic/$topicId',
      extra: TopicRouteExtra(
        serverUrl: server.serverUrl,
        categoriesById: categoriesById,
      ),
    );
  }

  Widget _buildSiteLogo(ServerAccount server, ThemeData theme) {
    final logoUrl = server.siteLogoUrl ?? server.faviconUrl;
    if (logoUrl != null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: logoUrl,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => Icon(
              Icons.forum_rounded,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.forum_rounded,
        size: 18,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _NotificationBadge extends ConsumerWidget {
  final String serverUrl;
  final IconData icon;

  const _NotificationBadge({required this.serverUrl, required this.icon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationListProvider(serverUrl)).unreadCount;
    if (unread == 0) return Icon(icon);
    return Badge.count(count: unread, child: Icon(icon));
  }
}

class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final pendingCount = ref.watch(pendingActionCountProvider);
    final theme = Theme.of(context);

    if (connectivity.isOnline && !connectivity.wasOffline) {
      return const SizedBox.shrink();
    }

    if (connectivity.wasOffline) {
      return Material(
        color: theme.colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.cloud_done_rounded, size: 16,
                  color: theme.colorScheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Text('Back online',
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer)),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(connectivityProvider.notifier).dismissReconnected(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 16,
                color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 8),
            Text('Offline — viewing cached content',
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer)),
            if (pendingCount > 0) ...[
              const Spacer(),
              Text('$pendingCount pending',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _BootstrapError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: theme.colorScheme.error.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load site data',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
