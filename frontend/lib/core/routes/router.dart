import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../core/widgets/main_shell_screen.dart';
import '../../core/theme/app_colors.dart';

import '../../screens/auth/login_screen.dart';
import '../../features/auth/screens/pin_setup_screen.dart';
import '../../features/auth/screens/pin_entry_screen.dart';
import '../../features/workspace/screens/workspace_screen.dart';
import '../../features/crm/screens/crm_leads_screen.dart';
import '../../features/logistics/screens/logistics_hub_screen.dart';
import '../../features/execution/screens/execution_hub_screen.dart';
import '../../features/hr/screens/hr_hub_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref ref;
  RouterNotifier(this.ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;

      if (auth.isLoading) return '/loading';
      if (!auth.isAuthenticated) return '/login';
      if (auth.needsPinSetup) return '/setup-pin';
      if (!auth.sessionUnlocked) return '/pin-entry';

      final authRoutes = ['/login', '/setup-pin', '/pin-entry', '/loading'];
      if (authRoutes.contains(path)) return '/';

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/setup-pin',
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: '/pin-entry',
        builder: (context, state) => const PinEntryScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            redirect: (context, state) => '/home',
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) {
              final auth = ref.read(authProvider);
              final isAdmin = auth.userRole == 'admin' || auth.userRole == 'super_admin';
              return WorkspaceScreen(isAdmin: isAdmin);
            },
          ),
          GoRoute(
            path: '/crm',
            builder: (context, state) => const CrmLeadsScreen(),
          ),
          GoRoute(
            path: '/logistics',
            builder: (context, state) {
              final auth = ref.read(authProvider);
              final isAdmin = auth.userRole == 'admin' || auth.userRole == 'super_admin';
              return LogisticsHubScreen(isAdmin: isAdmin);
            },
          ),
          GoRoute(
            path: '/execution',
            builder: (context, state) {
              final auth = ref.read(authProvider);
              final isAdmin = auth.userRole == 'admin' || auth.userRole == 'super_admin';
              return ExecutionHubScreen(isAdmin: isAdmin);
            },
          ),
          GoRoute(
            path: '/hr',
            builder: (context, state) => const HrHubScreen(),
          ),
        ],
      ),
    ],
  );
});
