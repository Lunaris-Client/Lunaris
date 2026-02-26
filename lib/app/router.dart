import 'package:go_router/go_router.dart';
import 'package:lunaris/features/server/server_list_screen.dart';
import 'package:lunaris/features/server/add_server_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ServerListScreen(),
    ),
    GoRoute(
      path: '/add-server',
      builder: (context, state) => const AddServerScreen(),
    ),
  ],
);
