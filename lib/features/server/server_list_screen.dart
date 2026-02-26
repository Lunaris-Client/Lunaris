import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/features/server/add_server_screen.dart';

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
          ? _EmptyState(onAdd: () => _navigateToAddServer(context))
          : _ServerList(
              servers: servers,
              onAdd: () => _navigateToAddServer(context),
              onRemove: (url) =>
                  ref.read(serverAccountsProvider.notifier).remove(url),
              onTap: (account) => _onServerTap(context, account),
            ),
      floatingActionButton: servers.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _navigateToAddServer(context),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _navigateToAddServer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddServerScreen()),
    );
  }

  void _onServerTap(BuildContext context, ServerAccount account) {
    if (!account.isAuthenticated) {
      // TODO: navigate to auth flow
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tap to log in to ${account.siteName}')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connected to ${account.siteName}')),
    );
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

  void _confirmRemove(BuildContext context, ServerAccount account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Server'),
        content: Text('Remove ${account.siteName}? '
            'You can add it back later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRemove(account.serverUrl);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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
        return false; // dialog handles the actual removal
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: _ServerAvatar(
          logoUrl: account.siteLogoUrl,
          faviconUrl: account.faviconUrl,
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
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  final String? logoUrl;
  final String? faviconUrl;

  const _ServerAvatar({this.logoUrl, this.faviconUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = faviconUrl ?? logoUrl;

    if (imageUrl == null) {
      return CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.forum_rounded,
            color: theme.colorScheme.onPrimaryContainer, size: 20),
      );
    }

    return CircleAvatar(
      backgroundColor: theme.colorScheme.primaryContainer,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Icon(Icons.forum_rounded,
              color: theme.colorScheme.onPrimaryContainer, size: 20),
        ),
      ),
    );
  }
}
