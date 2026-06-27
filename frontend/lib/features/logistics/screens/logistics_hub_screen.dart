import 'package:flutter/material.dart';
import 'logistics_orders_screen.dart';
import 'vendors_list_screen.dart';
import 'my_dispatches_screen.dart';
import 'dispatch_recording_screen.dart';
import '../../../shared/widgets/module_tile.dart';

class LogisticsHubScreen extends StatelessWidget {
  final bool isAdmin;

  const LogisticsHubScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistics'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
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
              color: const Color(0xFF0061a4),
              onTap: () => pushScreen(context, const LogisticsOrdersScreen()),
            ),
          ModuleTile(
            title: 'Vendors',
            icon: Icons.store,
            color: const Color(0xFF006e1c),
            onTap: () => pushScreen(context, const VendorsListScreen()),
          ),
          ModuleTile(
            title: 'My Dispatches',
            icon: Icons.local_shipping,
            color: const Color(0xFF904d00),
            onTap: () => pushScreen(context, const MyDispatchesScreen()),
          ),
          ModuleTile(
            title: 'Log Dispatch',
            icon: Icons.edit_note,
            color: const Color(0xFF5e4300),
            onTap: () => pushScreen(context, const DispatchRecordingScreen()),
          ),
        ],
      ),
    );
  }
}
