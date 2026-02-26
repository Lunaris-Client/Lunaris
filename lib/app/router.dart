import 'package:go_router/go_router.dart';
import 'package:lunaris/core/models/server_account.dart';
import 'package:lunaris/features/server/server_list_screen.dart';
import 'package:lunaris/features/server/add_server_screen.dart';
import 'package:lunaris/features/auth/login_screen.dart';
import 'package:lunaris/features/home/home_shell.dart';

GoRouter createRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ServerListScreen(),
      ),
      GoRoute(
        path: '/add-server',
        builder: (context, state) => const AddServerScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(account: state.extra! as ServerAccount),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeShell(),
      ),
    ],
  );
}
