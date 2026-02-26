import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/features/home/server_switcher_drawer.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final avatarUrl = server.avatarTemplate != null
        ? '${server.serverUrl}${server.avatarTemplate!.replaceAll('{size}', '40')}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(server.siteName),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: avatarUrl != null
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: CachedNetworkImageProvider(avatarUrl),
                  )
                : CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(Icons.person_rounded,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
          ),
        ],
      ),
      drawer: const ServerSwitcherDrawer(),
      body: siteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _BootstrapError(
          error: error,
          onRetry: () =>
              ref.read(siteDataProvider(server.serverUrl).notifier).refresh(),
        ),
        data: (siteData) {
          if (siteData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _HomeContent(
            siteName: server.siteName,
            username: server.username,
            categoryCount: siteData.categories.length,
            tagCount: siteData.topTags.length,
            filterCount: siteData.filters.length,
            fetchedAt: siteData.fetchedAt,
          );
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final String siteName;
  final String? username;
  final int categoryCount;
  final int tagCount;
  final int filterCount;
  final DateTime fetchedAt;

  const _HomeContent({
    required this.siteName,
    required this.username,
    required this.categoryCount,
    required this.tagCount,
    required this.filterCount,
    required this.fetchedAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(siteName, style: theme.textTheme.headlineSmall),
          if (username != null) ...[
            const SizedBox(height: 4),
            Text(
              'Logged in as $username',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _InfoChip(
            icon: Icons.category_rounded,
            label: '$categoryCount categories',
          ),
          const SizedBox(height: 8),
          _InfoChip(
            icon: Icons.tag_rounded,
            label: '$tagCount top tags',
          ),
          const SizedBox(height: 8),
          _InfoChip(
            icon: Icons.filter_list_rounded,
            label: '$filterCount filters',
          ),
          const SizedBox(height: 16),
          Text(
            'Site data cached at ${fetchedAt.toLocal().toString().substring(0, 19)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
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
            Icon(Icons.cloud_off_rounded,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.6)),
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
