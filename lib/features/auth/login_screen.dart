import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

import 'package:lunaris/core/models/models.dart';
import 'package:lunaris/core/providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final ServerAccount account;
  const LoginScreen({super.key, required this.account});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _LoginState { idle, generatingKeys, waitingForBrowser, verifying, done, error }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoginState _state = _LoginState.idle;
  String? _error;
  CurrentUser? _currentUser;

  bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

  @override
  void dispose() {
    ref.read(authServiceProvider).clearPendingSession();
    super.dispose();
  }

  Future<void> _startAuth() async {
    final authService = ref.read(authServiceProvider);
    final apiClient = ref.read(discourseApiClientProvider);

    setState(() {
      _state = _LoginState.generatingKeys;
      _error = null;
    });

    try {
      final authUrl = await authService.buildAuthUrl(widget.account.serverUrl);

      setState(() => _state = _LoginState.waitingForBrowser);

      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        setState(() {
          _state = _LoginState.error;
          _error = 'Could not open browser. Copy this URL manually:\n$authUrl';
        });
        return;
      }

      Map<String, String> callbackParams;
      if (_isDesktop) {
        callbackParams = await authService.waitForDesktopCallback();
      } else {
        callbackParams = await _waitForDeepLink();
      }

      final payload = callbackParams['payload'];
      if (payload == null || payload.isEmpty) {
        setState(() {
          _state = _LoginState.error;
          _error = 'No payload received from server. Authorization may have been denied.';
        });
        return;
      }

      setState(() => _state = _LoginState.verifying);

      final result = authService.decryptPayload(payload);

      if (!authService.verifyNonce(result)) {
        setState(() {
          _state = _LoginState.error;
          _error = 'Security verification failed: nonce mismatch.';
        });
        return;
      }

      await authService.storeApiKey(widget.account.serverUrl, result.apiKey);

      final user = await apiClient.fetchCurrentUser(
        widget.account.serverUrl,
        result.apiKey,
      );

      final session = authService.pendingSession!;
      final updatedAccount = widget.account.copyWith(
        clientId: session.clientId,
        username: user.username,
        userId: user.id,
        avatarTemplate: user.avatarTemplate,
        trustLevel: user.trustLevel,
        isAuthenticated: true,
        lastSyncedAt: DateTime.now(),
      );

      await ref.read(serverAccountsProvider.notifier).update(updatedAccount);
      await authService.clearPendingSession();

      setState(() {
        _state = _LoginState.done;
        _currentUser = user;
      });
    } on DioException catch (e) {
      await authService.clearPendingSession();
      setState(() {
        _state = _LoginState.error;
        _error = e.response?.statusCode == 403
            ? 'Access denied. The API key may have been revoked.'
            : 'Network error: ${e.message}';
      });
    } catch (e) {
      await authService.clearPendingSession();
      setState(() {
        _state = _LoginState.error;
        _error = 'Authentication failed: $e';
      });
    }
  }

  Future<Map<String, String>> _waitForDeepLink() async {
    final appLinks = AppLinks();
    final uri = await appLinks.uriLinkStream.firstWhere(
      (uri) => uri.scheme == 'lunaris' && uri.host == 'auth_redirect',
    );
    return uri.queryParameters;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.account.siteName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 32),
            if (_state == _LoginState.done && _currentUser != null)
              _buildSuccess(theme)
            else ...[
              _buildStatusSection(theme),
              const SizedBox(height: 24),
              _buildActions(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final imageUrl =
        widget.account.siteLogoUrl ?? widget.account.faviconUrl;

    return Column(
      children: [
        if (imageUrl != null)
          CachedNetworkImage(
            imageUrl: imageUrl,
            height: 64,
            errorWidget: (_, __, ___) => Icon(
              Icons.forum_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          )
        else
          Icon(Icons.forum_rounded, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Log in to ${widget.account.siteName}',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          widget.account.serverUrl.replaceFirst(RegExp(r'^https?://'), ''),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(ThemeData theme) {
    return switch (_state) {
      _LoginState.idle => Card(
          color: theme.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.lock_open_rounded,
                    size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Lunaris uses the Discourse User API Key flow to authenticate.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your browser will open to approve access. '
                  'No password is sent to Lunaris.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      _LoginState.generatingKeys => _buildProgress(
          theme, 'Generating encryption keys...', Icons.vpn_key_rounded),
      _LoginState.waitingForBrowser => _buildProgress(
          theme, 'Waiting for browser authorization...', Icons.open_in_browser_rounded),
      _LoginState.verifying => _buildProgress(
          theme, 'Verifying credentials...', Icons.verified_user_rounded),
      _LoginState.error => _buildError(theme),
      _LoginState.done => const SizedBox.shrink(),
    };
  }

  Widget _buildProgress(ThemeData theme, String message, IconData icon) {
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded,
                color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error ?? 'Unknown error',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    final canStart = _state == _LoginState.idle || _state == _LoginState.error;
    return FilledButton.icon(
      onPressed: canStart ? _startAuth : null,
      icon: Icon(canStart ? Icons.login_rounded : Icons.hourglass_top_rounded),
      label: Text(switch (_state) {
        _LoginState.idle => 'Open Browser to Log In',
        _LoginState.error => 'Try Again',
        _ => 'Authenticating...',
      }),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    final user = _currentUser!;
    final avatarUrl = user.avatarTemplate != null
        ? '${widget.account.serverUrl}${user.avatarTemplate!.replaceAll('{size}', '120')}'
        : null;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (avatarUrl != null)
              CircleAvatar(
                radius: 40,
                backgroundImage: CachedNetworkImageProvider(avatarUrl),
              )
            else
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(Icons.person_rounded,
                    size: 40, color: theme.colorScheme.onPrimary),
              ),
            const SizedBox(height: 16),
            Text(
              user.name ?? user.username,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            if (user.name != null) ...[
              const SizedBox(height: 2),
              Text(
                '@${user.username}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
            if (user.title != null) ...[
              const SizedBox(height: 4),
              Text(
                user.title!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Icon(Icons.check_circle_rounded,
                size: 32, color: theme.colorScheme.onPrimaryContainer),
            const SizedBox(height: 8),
            Text(
              'Logged in successfully',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                ref.read(activeServerIdProvider.notifier).setActive(
                    widget.account.id);
                context.go('/home');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
