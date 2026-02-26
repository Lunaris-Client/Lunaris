import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/app/router.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/theme/lunaris_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final initialRoute = _resolveInitialRoute(prefs);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: LunarisApp(initialRoute: initialRoute),
    ),
  );
}

String _resolveInitialRoute(SharedPreferences prefs) {
  final activeId = prefs.getString('active_server_id');
  if (activeId == null) return '/';
  final raw = prefs.getString('server_accounts');
  if (raw == null) return '/';
  final list = jsonDecode(raw) as List;
  final hasActive =
      list.any((e) => e['id'] == activeId && e['isAuthenticated'] == true);
  return hasActive ? '/home' : '/';
}

class LunarisApp extends StatefulWidget {
  final String initialRoute;
  const LunarisApp({super.key, required this.initialRoute});

  @override
  State<LunarisApp> createState() => _LunarisAppState();
}

class _LunarisAppState extends State<LunarisApp> {
  late final GoRouter _router = createRouter(widget.initialRoute);

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
