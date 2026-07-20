import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/sync_banner.dart';
import '../../core/providers/cache_provider.dart';

class MainShellScreen extends ConsumerWidget {
  final Widget child;

  const MainShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Boot cache sync
    ref.read(cacheBootSyncProvider);

    final labels = const ['Home', 'CRM', 'Logistics', 'Execution', 'HR'];

    final icons = const [
      Icons.home_outlined,
      Icons.contacts_outlined,
      Icons.local_shipping_outlined,
      Icons.task_alt_outlined,
      Icons.groups_outlined,
    ];

    final selectedIcons = const [
      Icons.home,
      Icons.contacts,
      Icons.local_shipping,
      Icons.task_alt,
      Icons.groups,
    ];

    final routes = const [
      '/home',
      '/crm',
      '/logistics',
      '/execution',
      '/hr',
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
          (i) => NavigationDestination(
            icon: Icon(icons[i]),
            selectedIcon: Icon(selectedIcons[i]),
            label: labels[i],
          ),
        ),
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context, List<String> routes) {
    final String location = GoRouterState.of(context).uri.path;
    for (var i = routes.length - 1; i >= 0; i--) {
      if (location.startsWith(routes[i])) return i;
    }
    return 0; // Home
  }
}
