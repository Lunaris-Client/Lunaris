import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/storage/content_cache.dart';
import 'package:lunaris/core/services/offline_action_service.dart';
import 'package:lunaris/core/providers/providers.dart';

class CacheSettingsScreen extends ConsumerStatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  ConsumerState<CacheSettingsScreen> createState() =>
      _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends ConsumerState<CacheSettingsScreen> {
  int _cacheSizeBytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final cache = ContentCache();
    final size = await cache.cacheSizeBytes();
    if (mounted) {
      setState(() {
        _cacheSizeBytes = size;
        _loading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = ref.watch(pendingActionCountProvider);
    final server = ref.watch(activeServerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cache & Offline')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.storage_rounded),
            title: const Text('Cache size'),
            subtitle: Text(
              _loading ? 'Calculating…' : _formatBytes(_cacheSizeBytes),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_rounded),
            title: const Text('Clear all cached content'),
            subtitle: const Text('Remove all offline data'),
            onTap: () async {
              final confirmed = await showAdaptiveDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog.adaptive(
                  title: const Text('Clear cache?'),
                  content: const Text(
                    'All cached topics and profiles will be removed.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ContentCache().clearAll();
                _loadCacheSize();
              }
            },
          ),
          if (server != null)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Clear cache for this server'),
              subtitle: Text(server.siteName),
              onTap: () async {
                await ContentCache().clearServer(server.serverUrl);
                _loadCacheSize();
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_upload_rounded),
            title: const Text('Pending offline actions'),
            subtitle: Text(
              pendingCount == 0
                  ? 'No pending actions'
                  : '$pendingCount action${pendingCount == 1 ? '' : 's'} queued',
            ),
          ),
          if (pendingCount > 0)
            ListTile(
              leading: Icon(
                Icons.sync_rounded,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Retry now'),
              subtitle: const Text('Attempt to sync pending actions'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final service = ref.read(offlineActionServiceProvider);
                final replayed = await service.replayAll();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Synced $replayed action${replayed == 1 ? '' : 's'}'),
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
