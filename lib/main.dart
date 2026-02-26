import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lunaris/app/router.dart';
import 'package:lunaris/core/providers/providers.dart';
import 'package:lunaris/ui/theme/lunaris_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const LunarisApp(),
    ),
  );
}

class LunarisApp extends StatelessWidget {
  const LunarisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Lunaris',
      debugShowCheckedModeBanner: false,
      theme: LunarisTheme.light(),
      darkTheme: LunarisTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
