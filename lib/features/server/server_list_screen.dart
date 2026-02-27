import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/widgets/adaptive_dialog.dart';
import 'package:lunaris/ui/widgets/server_icon.dart';

class ServerListScreen extends ConsumerWidget {
  const ServerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serverAccountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lunaris'),
        centerTitle: true,
      ),
      body: servers.isEmpty
          ? _EmptyState(onAdd: () => context.push('/add-server'))
          : _ServerList(
              servers: servers,
              onAdd: () => context.push('/add-server'),
              onRemove: (url) =>
                  ref.read(serverAccountsProvider.notifier).remove(url),
              onTap: (account) => _onServerTap(context, ref, account),
            ),
      floatingActionButton: servers.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => context.push('/add-server'),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _onServerTap(BuildContext context, WidgetRef ref, ServerAccount account) {
    if (!account.isAuthenticated) {
      context.push('/login', extra: account);
      return;
    }
    ref.read(activeServerIdProvider.notifier).setActive(account.id);
    context.go('/home');
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No servers yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a Discourse server to get started',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a Server'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerList extends StatelessWidget {
  final List<ServerAccount> servers;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<ServerAccount> onTap;

  const _ServerList({
    required this.servers,
    required this.onAdd,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final account = servers[index];
        return _ServerTile(
          account: account,
          onTap: () => onTap(account),
          onRemove: () => _confirmRemove(context, account),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, ServerAccount account) async {
    final confirmed = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Remove Server',
      content: 'Remove ${account.siteName}? You can add it back later.',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (confirmed == true) {
      onRemove(account.serverUrl);
    }
  }
}

class _ServerTile extends StatelessWidget {
  final ServerAccount account;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _ServerTile({
    required this.account,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(account.serverUrl),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_rounded, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        onRemove();
        return false;
      },
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, details.globalPosition),
        onLongPressStart: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ServerIcon(
          logoUrl: account.siteLogoUrl,
          faviconUrl: account.faviconUrl,
          size: 40,
        ),
        title: Text(
          account.siteName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account.serverUrl.replaceFirst(RegExp(r'^https?://'), ''),
              style: theme.textTheme.bodySmall,
            ),
            if (account.isAuthenticated && account.username != null)
              Text(
                'Logged in as ${account.username}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: account.isAuthenticated
            ? Icon(Icons.check_circle_rounded,
                color: theme.colorScheme.primary, size: 20)
            : Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
        onTap: onTap,
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final theme = Theme.of(context);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          onTap: onRemove,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 20, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text('Remove Server',
                  style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}
