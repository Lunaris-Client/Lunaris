import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/widgets/adaptive_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final server = ref.watch(activeServerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SettingsItem(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme, colors, display',
            onTap: () => context.push('/settings/theme'),
          ),
          _SettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Alerts, quiet hours, filters',
            onTap: () => context.push('/settings/notifications'),
          ),
          _SettingsItem(
            icon: Icons.lock_outlined,
            title: 'Security',
            subtitle: 'Biometric lock',
            onTap: () => context.push('/settings/security'),
          ),
          _SettingsItem(
            icon: Icons.storage_outlined,
            title: 'Cache & Offline',
            subtitle: 'Cached data, pending actions',
            onTap: () => context.push('/settings/cache'),
          ),
          const Divider(height: 1),
          _SettingsItem(
            icon: Icons.dns_outlined,
            title: 'Manage Servers',
            subtitle: 'Add, remove, or switch servers',
            onTap: () => context.go('/'),
          ),
          if (server != null) ...[
            const Divider(height: 1),
            _SettingsItem(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Log out of ${server.siteName}',
              destructive: true,
              onTap: () => _logout(context, ref, server),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _logout(
    BuildContext context,
    WidgetRef ref,
    ServerAccount server,
  ) async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Log Out',
      content: 'Log out of ${server.siteName}?',
      confirmLabel: 'Log Out',
    );

    if (confirmed != true || !context.mounted) return;

    final authService = ref.read(authServiceProvider);
    final apiClient = ref.read(discourseApiClientProvider);
    final accountsNotifier = ref.read(serverAccountsProvider.notifier);
    final activeNotifier = ref.read(activeServerIdProvider.notifier);

    final apiKey = await authService.loadApiKey(server.serverUrl);

    if (apiKey != null) {
      try {
        await apiClient.revokeApiKey(server.serverUrl, apiKey);
      } catch (_) {}
      await authService.deleteApiKey(server.serverUrl);
    }

    final resetAccount = server.copyWith(
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
      if (context.mounted) context.go('/home');
    } else {
      await activeNotifier.setActive(null);
      if (context.mounted) context.go('/');
    }
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;

    return ListTile(
      leading: Icon(icon, color: color ?? theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: color != null ? TextStyle(color: color) : null),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: destructive
              ? color?.withValues(alpha: 0.7)
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: destructive
          ? null
          : Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
      onTap: onTap,
    );
  }
}
