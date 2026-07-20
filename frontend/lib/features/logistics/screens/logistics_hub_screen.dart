import 'package:flutter/material.dart';
import 'logistics_orders_screen.dart';
import 'vendors_list_screen.dart';
import 'my_dispatches_screen.dart';
import 'dispatch_recording_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/module_tile.dart';
import '../../iam/screens/profile_screen.dart';

class LogisticsHubScreen extends StatelessWidget {
  final bool isAdmin;

  const LogisticsHubScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => pushScreen(context, const ProfileScreen()),
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(24),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          if (isAdmin)
            ModuleTile(
              title: 'Orders',
              icon: Icons.inventory_2,
              color: AppColors.primary,
              onTap: () => pushScreen(context, const LogisticsOrdersScreen()),
            ),
          ModuleTile(
            title: 'Vendors',
            icon: Icons.store,
            color: AppColors.secondary,
            onTap: () => pushScreen(context, const VendorsListScreen()),
          ),
          ModuleTile(
            title: 'My Dispatches',
            icon: Icons.local_shipping,
            color: AppColors.tertiary,
            onTap: () => pushScreen(context, const MyDispatchesScreen()),
          ),
          ModuleTile(
            title: 'Log Dispatch',
            icon: Icons.edit_note,
            color: AppColors.primary,
            onTap: () => pushScreen(context, const DispatchRecordingScreen()),
          ),
        ],
      ),
    );
  }
}
