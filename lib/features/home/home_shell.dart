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
import 'package:lunaris/core/providers/notification_provider.dart';
import 'package:lunaris/features/notifications/notification_list_view.dart';
import 'package:lunaris/features/topic/topic_view_screen.dart';

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

  void _onTabChanged(int index) {
    if (index == _currentTab) return;
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

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    final theme = Theme.of(context);
    final breakpoint = layoutBreakpointOf(MediaQuery.sizeOf(context).width);

    if (server == null || !server.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final siteAsync = ref.watch(siteDataProvider(server.serverUrl));

    ref.listen(siteDataProvider(server.serverUrl), (prev, next) {
      if (next.hasValue && next.value != null) {
        final service = ref.read(siteBootstrapServiceProvider);
        if (service.needsRefresh(next.value!)) {
          ref.read(siteDataProvider(server.serverUrl).notifier).refresh();
        }
      }
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
          if (_currentTab == 2) _buildMarkAllReadButton(server.serverUrl),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child:
                avatarUrl != null
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
        ],
      ),
      drawer: const ServerSwitcherDrawer(),
      body: siteAsync.when(
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
      bottomNavigationBar:
          breakpoint == LayoutBreakpoint.mobile
              ? NavigationBar(
                selectedIndex: _currentTab,
                onDestinationSelected: _onTabChanged,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.forum_outlined),
                    selectedIcon: Icon(Icons.forum_rounded),
                    label: 'Feed',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.category_outlined),
                    selectedIcon: Icon(Icons.category_rounded),
                    label: 'Categories',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.notifications_outlined),
                    selectedIcon: Icon(Icons.notifications_rounded),
                    label: 'Notifications',
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
      default:
        content = _buildFeedTab(siteData, server.serverUrl);
    }

    if (breakpoint == LayoutBreakpoint.mobile) return content;

    final categoriesById = {for (final c in siteData.categories) c.id: c};

    return Row(
      children: [
        SidebarNavigation(
          selectedIndex: _currentTab,
          onDestinationSelected: _onTabChanged,
          extended: breakpoint == LayoutBreakpoint.desktop,
          activeServer: breakpoint == LayoutBreakpoint.desktop ? server : null,
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
