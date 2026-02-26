import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/core/models/site_category.dart';
import 'package:lunaris/features/server/server_list_screen.dart';
import 'package:lunaris/features/server/add_server_screen.dart';
import 'package:lunaris/features/auth/login_screen.dart';
import 'package:lunaris/features/home/home_shell.dart';
import 'package:lunaris/features/settings/notification_settings_screen.dart';
import 'package:lunaris/features/topic/topic_view_screen.dart';

class TopicRouteExtra {
  final String serverUrl;
  final String? topicTitle;
  final Map<int, SiteCategory>? categoriesById;

  const TopicRouteExtra({
    required this.serverUrl,
    this.topicTitle,
    this.categoriesById,
  });
}

GoRouter createRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ServerListScreen()),
      GoRoute(
        path: '/add-server',
        builder: (context, state) => const AddServerScreen(),
      ),
      GoRoute(
        path: '/login',
        builder:
            (context, state) =>
                LoginScreen(account: state.extra! as ServerAccount),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/topic/:id',
        builder: (context, state) {
          final topicId = int.parse(state.pathParameters['id']!);
          final extra = state.extra as TopicRouteExtra?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('Missing navigation data')),
            );
          }
          return TopicViewScreen(
            serverUrl: extra.serverUrl,
            topicId: topicId,
            topicTitle: extra.topicTitle,
            categoriesById: extra.categoriesById,
          );
        },
      ),
    ],
  );
}
