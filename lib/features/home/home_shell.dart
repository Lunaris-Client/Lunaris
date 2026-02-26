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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_rounded,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(server.siteName, style: theme.textTheme.headlineSmall),
            if (server.username != null) ...[
              const SizedBox(height: 4),
              Text(
                'Logged in as ${server.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
