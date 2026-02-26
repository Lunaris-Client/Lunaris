import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/core/models/site_data.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/features/home/server_switcher_drawer.dart';
import 'package:lunaris/features/feed/topic_list_view.dart';
import 'package:lunaris/features/feed/feed_filter_bar.dart';
import 'package:lunaris/features/feed/category_filter_sheet.dart';
import 'package:lunaris/features/feed/tag_filter_sheet.dart';
import 'package:lunaris/features/categories/category_browser_view.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentTab = 0;
  String _activeFilter = 'latest';
  SiteCategory? _selectedCategory;
  String? _selectedTag;
  String _selectedPeriod = 'all';

  void _onFilterChanged(String filter) {
    if (filter == _activeFilter) return;
    setState(() => _activeFilter = filter);
  }

  void _onPeriodChanged(String period) {
    if (period == _selectedPeriod) return;
    setState(() => _selectedPeriod = period);
  }

  void _onCategoryBrowseSelected(SiteCategory category) {
    setState(() {
      _selectedCategory = category;
      _selectedTag = null;
      _activeFilter = 'latest';
      _currentTab = 0;
    });
  }

  Future<void> _showCategorySheet(List<SiteCategory> categories) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => CategoryFilterSheet(
            categories: categories,
            selected: _selectedCategory,
          ),
    );
    if (!mounted) return;
    if (result == 'clear') {
      setState(() => _selectedCategory = null);
    } else if (result is SiteCategory) {
      setState(() => _selectedCategory = result);
    }
  }

  Future<void> _showTagSheet(List<String> tags) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TagFilterSheet(tags: tags, selected: _selectedTag),
    );
    if (!mounted) return;
    if (result == 'clear') {
      setState(() => _selectedTag = null);
    } else if (result is String) {
      setState(() => _selectedTag = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(activeServerProvider);
    final theme = Theme.of(context);

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
            ? '${server.serverUrl}${server.avatarTemplate!.replaceAll('{size}', '40')}'
            : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(server.siteName),
        actions: [
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
          return _currentTab == 0
              ? _buildFeedTab(siteData, server.serverUrl)
              : CategoryBrowserView(
                siteData: siteData,
                onCategorySelected: _onCategoryBrowseSelected,
              );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
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
        ],
      ),
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
          activeCategory: _selectedCategory,
          onCategoryTap: () => _showCategorySheet(siteData.categories),
          onCategoryClear: () => setState(() => _selectedCategory = null),
          activeTag: _selectedTag,
          onTagTap: () => _showTagSheet(siteData.topTags),
          onTagClear: () => setState(() => _selectedTag = null),
        ),
        Expanded(
          child: TopicListView(
            key: ValueKey(
              '$_activeFilter-${_selectedCategory?.id}-$_selectedTag-$effectivePeriod',
            ),
            serverUrl: serverUrl,
            siteData: siteData,
            filter: _activeFilter,
            categoryId: _selectedCategory?.id,
            categorySlug: _selectedCategory?.slug,
            tagName: _selectedTag,
            period: effectivePeriod,
          ),
        ),
      ],
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
