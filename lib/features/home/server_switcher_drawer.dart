import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/widgets/adaptive_dialog.dart';

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
                        leading: _ServerIcon(logoUrl: account.siteLogoUrl, faviconUrl: account.faviconUrl),
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
              leading: const Icon(Icons.dns_rounded),
              title: const Text('Manage Servers'),
              onTap: () {
                Navigator.pop(context);
                context.go('/');
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notification Settings'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Appearance'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings/theme');
              },
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('Cache & Offline'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings/cache');
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outlined),
              title: const Text('Security'),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings/security');
              },
            ),
            if (activeServer != null)
              ListTile(
                leading: Icon(
                  Icons.logout_rounded,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Log Out',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () => _logout(context, ref),
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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final activeServer = ref.read(activeServerProvider);
    if (activeServer == null) return;

    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Log Out',
      content: 'Log out of ${activeServer.siteName}?',
      confirmLabel: 'Log Out',
    );

    if (confirmed != true || !context.mounted) return;

    final authService = ref.read(authServiceProvider);
    final apiClient = ref.read(discourseApiClientProvider);
    final accountsNotifier = ref.read(serverAccountsProvider.notifier);
    final activeNotifier = ref.read(activeServerIdProvider.notifier);

    Navigator.pop(context);

    final apiKey = await authService.loadApiKey(activeServer.serverUrl);

    if (apiKey != null) {
      try {
        await apiClient.revokeApiKey(activeServer.serverUrl, apiKey);
      } catch (_) {}
      await authService.deleteApiKey(activeServer.serverUrl);
    }

    final resetAccount = activeServer.copyWith(
      isAuthenticated: false,
      username: null,
      userId: null,
      avatarTemplate: null,
      trustLevel: null,
      clientId: null,
      lastSyncedAt: null,
    );
    await accountsNotifier.update(resetAccount);

    final remaining =
        ref
            .read(serverAccountsProvider)
            .where((s) => s.isAuthenticated)
            .toList();

    if (remaining.isNotEmpty) {
      await activeNotifier.setActive(remaining.first.id);
    } else {
      await activeNotifier.setActive(null);
      if (context.mounted) {
        context.go('/');
      }
    }
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
      leading: _ServerIcon(logoUrl: account.siteLogoUrl, faviconUrl: account.faviconUrl),
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

class _ServerIcon extends StatelessWidget {
  final String? logoUrl;
  final String? faviconUrl;

  const _ServerIcon({this.logoUrl, this.faviconUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = logoUrl ?? faviconUrl;

    if (imageUrl == null) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.forum_rounded,
          size: 16,
          color: theme.colorScheme.onPrimaryContainer,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorWidget:
              (_, __, ___) => Icon(
                Icons.forum_rounded,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer,
              ),
        ),
      ),
    );
  }
}
