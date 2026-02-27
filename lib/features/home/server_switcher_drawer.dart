import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/widgets/server_icon.dart';

class ServerSwitcherDrawer extends ConsumerWidget {
  const ServerSwitcherDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serverAccountsProvider);
    final activeId = ref.watch(activeServerIdProvider);
    final activeServer = ref.watch(activeServerProvider);
    final theme = Theme.of(context);

    final authenticated = servers.where((s) => s.isAuthenticated).toList();
    final unauthenticated = servers.where((s) => !s.isAuthenticated).toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, activeServer),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (authenticated.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'Servers',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final account in authenticated)
                      _ServerTile(
                        account: account,
                        isActive: account.id == activeId,
                        onTap: () => _switchServer(context, ref, account),
                      ),
                  ],
                  if (unauthenticated.isNotEmpty) ...[
                    if (authenticated.isNotEmpty) const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Not Logged In',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final account in unauthenticated)
                      ListTile(
                        leading: ServerIcon(logoUrl: account.siteLogoUrl, faviconUrl: account.faviconUrl),
                        title: Text(account.siteName),
                        subtitle: Text(
                          'Tap to log in',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          context.push('/login', extra: account);
                        },
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Add Server'),
              onTap: () {
                Navigator.pop(context);
                context.push('/add-server');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ServerAccount? activeServer) {
    if (activeServer == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Row(
          children: [
            Icon(
              Icons.dark_mode_rounded,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Lunaris',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final avatarUrl =
        activeServer.avatarTemplate != null
            ? '${activeServer.serverUrl}${activeServer.avatarTemplate!.replaceAll('{size}', '80')}'
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        children: [
          if (avatarUrl != null)
            CircleAvatar(
              radius: 24,
              backgroundImage: CachedNetworkImageProvider(avatarUrl),
            )
          else
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person_rounded,
                size: 24,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeServer.username ?? 'Unknown',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  activeServer.siteName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _switchServer(
    BuildContext context,
    WidgetRef ref,
    ServerAccount account,
  ) {
    ref.read(activeServerIdProvider.notifier).setActive(account.id);
    Navigator.pop(context);
  }
}

class _ServerTile extends StatelessWidget {
  final ServerAccount account;
  final bool isActive;
  final VoidCallback onTap;

  const _ServerTile({
    required this.account,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      selected: isActive,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
      leading: ServerIcon(logoUrl: account.siteLogoUrl, faviconUrl: account.faviconUrl),
      title: Text(
        account.siteName,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle:
          account.username != null
              ? Text(account.username!, style: theme.textTheme.bodySmall)
              : null,
      trailing:
          isActive
              ? Icon(
                Icons.check_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              )
              : null,
      onTap: onTap,
    );
  }
}
