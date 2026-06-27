import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/staff/staff_home_screen.dart';
import '../../features/crm/screens/crm_leads_screen.dart';
import '../../features/logistics/screens/logistics_hub_screen.dart';
import '../../features/execution/screens/execution_hub_screen.dart';
import '../../features/auth/screens/more_menu_screen.dart';
import '../widgets/sync_banner.dart';

/// App shell with bottom navigation (HR, CRM, Logistics, Execution, More).
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).userRole;
    final isAdmin = role == 'admin' || role == 'super_admin';

    final pages = <Widget>[
      isAdmin ? const AdminDashboardScreen() : const StaffHomeScreen(),
      const CrmLeadsScreen(),
      LogisticsHubScreen(isAdmin: isAdmin),
      ExecutionHubScreen(isAdmin: isAdmin),
      MoreMenuScreen(isAdmin: isAdmin),
    ];

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

    return Scaffold(
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: List.generate(
          labels.length,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}
