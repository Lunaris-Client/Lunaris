import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/app/router.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/models/models.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/theme/lunaris_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final initialRoute = await _resolveInitialRoute(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: LunarisApp(initialRoute: initialRoute),
    ),
  );
}

Future<String> _resolveInitialRoute(SharedPreferences prefs) async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final handled = await _handleAuthDeepLink(prefs);
    if (handled) return '/home';
  }

  final activeId = prefs.getString('active_server_id');
  if (activeId == null) return '/';
  final raw = prefs.getString('server_accounts');
  if (raw == null) return '/';
  final list = jsonDecode(raw) as List;
  final hasActive =
      list.any((e) => e['id'] == activeId && e['isAuthenticated'] == true);
  return hasActive ? '/home' : '/';
}

Future<bool> _handleAuthDeepLink(SharedPreferences prefs) async {
  try {
    final appLinks = AppLinks();
    final initialLink = await appLinks.getInitialLink();

    if (initialLink == null ||
        initialLink.scheme != 'lunaris' ||
        initialLink.host != 'auth_redirect') {
      return false;
    }

    final payload = initialLink.queryParameters['payload'];
    if (payload == null || payload.isEmpty) return false;

    final authService = AuthService();
    final session = await authService.restorePendingSession();
    if (session == null) return false;

    final result = authService.decryptPayload(payload);
    if (!authService.verifyNonce(result)) return false;

    await authService.storeApiKey(session.serverUrl, result.apiKey);

    String? username;
    int? userId;
    String? avatarTemplate;
    int? trustLevel;

    try {
      final apiClient = DiscourseApiClient();
      final user = await apiClient.fetchCurrentUser(
        session.serverUrl,
        result.apiKey,
      );
      username = user.username;
      userId = user.id;
      avatarTemplate = user.avatarTemplate;
      trustLevel = user.trustLevel;
    } catch (_) {}

    final raw = prefs.getString('server_accounts');
    if (raw == null) {
      await authService.clearPendingSession();
      return false;
    }

    final list = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final idx = list.indexWhere((e) => e['serverUrl'] == session.serverUrl);
    if (idx < 0) {
      await authService.clearPendingSession();
      return false;
    }

    list[idx] = {
      ...list[idx],
      'clientId': session.clientId,
      if (username != null) 'username': username,
      if (userId != null) 'userId': userId,
      if (avatarTemplate != null) 'avatarTemplate': avatarTemplate,
      if (trustLevel != null) 'trustLevel': trustLevel,
      'isAuthenticated': true,
      'lastSyncedAt': DateTime.now().toIso8601String(),
    };

    await prefs.setString('server_accounts', jsonEncode(list));
    await prefs.setString('active_server_id', list[idx]['id'] as String);

    await authService.clearPendingSession();
    return true;
  } catch (_) {
    return false;
  }
}

class LunarisApp extends ConsumerStatefulWidget {
  final String initialRoute;
  const LunarisApp({super.key, required this.initialRoute});

  @override
  ConsumerState<LunarisApp> createState() => _LunarisAppState();
}

class _LunarisAppState extends ConsumerState<LunarisApp> {
  late final GoRouter _router = createRouter(widget.initialRoute);
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _linkSub = AppLinks().uriLinkStream.listen(_onDeepLink);
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _router.dispose();
    super.dispose();
  }

  void _onDeepLink(Uri uri) {
    if (uri.scheme == 'lunaris' && uri.host == 'auth_redirect') {
      _processAuthRedirect(uri);
    }
  }

  Future<void> _processAuthRedirect(Uri uri) async {
    final payload = uri.queryParameters['payload'];
    if (payload == null || payload.isEmpty) return;

    try {
      final authService = ref.read(authServiceProvider);
      final session = await authService.restorePendingSession();
      if (session == null) return;

      final result = authService.decryptPayload(payload);
      if (!authService.verifyNonce(result)) return;

      await authService.storeApiKey(session.serverUrl, result.apiKey);

      final apiClient = ref.read(discourseApiClientProvider);
      CurrentUser? user;
      try {
        user = await apiClient.fetchCurrentUser(
          session.serverUrl,
          result.apiKey,
        );
      } catch (_) {}

      final accounts = ref.read(serverAccountsProvider);
      final existing = accounts
          .where((a) => a.serverUrl == session.serverUrl)
          .firstOrNull;
      if (existing == null) return;

      final updated = existing.copyWith(
        clientId: session.clientId,
        username: user?.username,
        userId: user?.id,
        avatarTemplate: user?.avatarTemplate,
        trustLevel: user?.trustLevel,
        isAuthenticated: true,
        lastSyncedAt: DateTime.now(),
      );

      await ref.read(serverAccountsProvider.notifier).update(updated);
      await ref.read(activeServerIdProvider.notifier).setActive(updated.id);
      await authService.clearPendingSession();

      _router.go('/home');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lunaris',
      debugShowCheckedModeBanner: false,
      theme: LunarisTheme.light(),
      darkTheme: LunarisTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
