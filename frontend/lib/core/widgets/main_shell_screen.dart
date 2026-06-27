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

    final labels = isAdmin
        ? const ['Team', 'CRM', 'Logistics', 'Execution', 'More']
        : const ['Home', 'CRM', 'Logistics', 'Execution', 'More'];

    final icons = isAdmin
        ? const [
            Icons.groups,
            Icons.contacts,
            Icons.local_shipping,
            Icons.construction,
            Icons.more_horiz,
          ]
        : const [
            Icons.home,
            Icons.contacts,
            Icons.local_shipping,
            Icons.construction,
            Icons.more_horiz,
          ];

    final routes = [
      '/',
      '/crm',
      '/logistics',
      '/execution',
      '/more',
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
    if (location.startsWith('/crm')) return 1;
    if (location.startsWith('/logistics')) return 2;
    if (location.startsWith('/execution')) return 3;
    if (location.startsWith('/more')) return 4;
    return 0; // Home / Team
  }
}
