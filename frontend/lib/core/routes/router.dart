import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../core/widgets/main_shell_screen.dart';

import '../../screens/auth/login_screen.dart';
import '../../features/auth/screens/pin_setup_screen.dart';
import '../../features/auth/screens/pin_entry_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/staff/staff_home_screen.dart';
import '../../features/crm/screens/crm_leads_screen.dart';
import '../../features/crm/screens/crm_lead_detail_screen.dart';
import '../../features/logistics/screens/logistics_hub_screen.dart';
import '../../features/execution/screens/execution_hub_screen.dart';
import '../../features/auth/screens/more_menu_screen.dart';

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
          body: Center(child: CircularProgressIndicator(color: Color(0xFF0061a4))),
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
            builder: (context, state) {
              final auth = ref.read(authProvider);
              final isAdmin = auth.userRole == 'admin' || auth.userRole == 'super_admin';
              return isAdmin ? const AdminDashboardScreen() : const StaffHomeScreen();
            },
          ),
          GoRoute(
            path: '/crm',
            builder: (context, state) => const CrmLeadsScreen(),
            routes: [
              GoRoute(
                path: 'lead/:id',
                builder: (context, state) {
                  final idStr = state.pathParameters['id'];
                  final id = int.tryParse(idStr ?? '');
                  if (id == null) return const Scaffold(body: Center(child: Text('Invalid Lead ID')));
                  return CrmLeadDetailScreen(leadId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/logistics',
            builder: (context, state) {
              final auth = ref.read(authProvider);
              return LogisticsHubScreen(isAdmin: auth.userRole == 'admin' || auth.userRole == 'super_admin');
            },
          ),
          GoRoute(
            path: '/execution',
            builder: (context, state) {
              final auth = ref.read(authProvider);
              return ExecutionHubScreen(isAdmin: auth.userRole == 'admin' || auth.userRole == 'super_admin');
            },
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) {
              final auth = ref.read(authProvider);
              return MoreMenuScreen(isAdmin: auth.userRole == 'admin' || auth.userRole == 'super_admin');
            },
          ),
        ],
      ),
    ],
  );
});
