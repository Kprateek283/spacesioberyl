import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../widgets/sync_banner.dart';
import '../../core/providers/cache_provider.dart';

class MainShellScreen extends ConsumerWidget {
  final Widget child;

  const MainShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).userRole;
    final isAdmin = role == 'admin' || role == 'super_admin';
    
    // Boot cache sync
    ref.read(cacheBootSyncProvider);

    final labels = const ['Workspace', 'Pipeline', 'Profile'];

    final icons = const [
      Icons.dashboard,
      Icons.view_kanban,
      Icons.person,
    ];

    final routes = [
      '/workspace',
      '/pipeline',
      '/profile',
    ];

    int currentIndex = _calculateSelectedIndex(context, routes);

    return Scaffold(
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(routes[i]),
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context, List<String> routes) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/pipeline')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0; // Workspace
  }
}
