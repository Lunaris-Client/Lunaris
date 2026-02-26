import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:lunaris/core/models/models.dart';
import 'package:lunaris/core/providers/providers.dart';

class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key});

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  ServerInfo? _serverInfo;
  bool _isProbing = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _probeServer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProbing = true;
      _error = null;
      _serverInfo = null;
    });

    try {
      final api = ref.read(discourseApiClientProvider);
      final info = await api.probeServer(_urlController.text);
      setState(() => _serverInfo = info);
    } on DioException catch (e) {
      setState(() {
        _error = switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.receiveTimeout =>
            'Connection timed out. Check the URL and try again.',
          DioExceptionType.connectionError =>
            'Could not connect. Is the URL correct?',
          _ => e.response?.statusCode == 404
              ? 'Not a Discourse server (404).'
              : 'Connection failed: ${e.message}',
        };
      });
    } catch (e) {
      setState(() => _error = 'Unexpected error: $e');
    } finally {
      setState(() => _isProbing = false);
    }
  }

  Future<void> _addServer() async {
    if (_serverInfo == null) return;

    final info = _serverInfo!;
    final account = ServerAccount(
      id: const Uuid().v4(),
      serverUrl: info.url,
      siteName: info.siteName,
      siteLogoUrl: info.logoUrl,
      siteDescription: info.description,
      faviconUrl: info.faviconUrl,
    );

    await ref.read(serverAccountsProvider.notifier).add(account);

    if (mounted) {
      Navigator.of(context).pop(account);
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter a server URL';
    final trimmed = value.trim();
    if (trimmed.contains(' ')) return 'URL cannot contain spaces';
    if (!trimmed.contains('.')) return 'Enter a valid domain';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Server')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.dns_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Connect to a Discourse server',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the URL of any Discourse forum',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _urlController,
                validator: _validateUrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.go,
                onFieldSubmitted: (_) => _probeServer(),
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'meta.discourse.org',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: _isProbing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isProbing ? null : _probeServer,
              icon: const Icon(Icons.search_rounded),
              label: Text(_isProbing ? 'Checking...' : 'Verify Server'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],
            if (_serverInfo != null) ...[
              const SizedBox(height: 24),
              _ServerPreviewCard(
                info: _serverInfo!,
                onAdd: _addServer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerPreviewCard extends StatelessWidget {
  final ServerInfo info;
  final VoidCallback onAdd;

  const _ServerPreviewCard({required this.info, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _SiteLogo(url: info.logoUrl, faviconUrl: info.faviconUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.siteName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.url,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
            if (info.description != null &&
                info.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                info.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Server'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteLogo extends StatelessWidget {
  final String? url;
  final String? faviconUrl;

  const _SiteLogo({this.url, this.faviconUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = url ?? faviconUrl;

    if (imageUrl == null) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.forum_rounded,
            color: theme.colorScheme.onPrimaryContainer),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        placeholder: (_, __) => Container(
          width: 48,
          height: 48,
          color: theme.colorScheme.primaryContainer,
          child: Icon(Icons.forum_rounded,
              color: theme.colorScheme.onPrimaryContainer, size: 24),
        ),
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: 24,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.forum_rounded,
              color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
