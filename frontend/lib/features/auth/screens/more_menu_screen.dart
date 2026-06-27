import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/hr/screens/my_attendance_screen.dart';
import 'package:frontend/features/hr/screens/my_leaves_screen.dart';
import 'package:frontend/features/hr/screens/my_expenses_screen.dart';
import 'package:frontend/features/hr/screens/admin_leaves_screen.dart';
import 'package:frontend/features/hr/screens/admin_expenses_screen.dart';
import 'package:frontend/features/iam/screens/iam_users_screen.dart';
import 'package:frontend/features/iam/screens/profile_screen.dart';
import 'package:frontend/features/crm/screens/crm_followups_screen.dart';
import 'package:frontend/features/crm/screens/crm_complaints_screen.dart';
import 'package:frontend/shared/widgets/module_tile.dart';

class MoreMenuScreen extends ConsumerWidget {
  final bool isAdmin;

  const MoreMenuScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).userRole;

    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(24),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          ModuleTile(
            title: 'My Attendance',
            icon: Icons.access_time,
            color: const Color(0xFF0061a4),
            onTap: () => pushScreen(context, const MyAttendanceScreen()),
          ),
          ModuleTile(
            title: 'My Leaves',
            icon: Icons.beach_access,
            color: const Color(0xFF006e1c),
            onTap: () => pushScreen(context, const MyLeavesScreen()),
          ),
          ModuleTile(
            title: 'My Expenses',
            icon: Icons.receipt_long,
            color: const Color(0xFF904d00),
            onTap: () => pushScreen(context, const MyExpensesScreen()),
          ),
          ModuleTile(
            title: 'Follow-ups',
            icon: Icons.phone_callback,
            color: const Color(0xFF5e4300),
            onTap: () => pushScreen(context, const CrmFollowupsScreen()),
          ),
          ModuleTile(
            title: 'Complaints',
            icon: Icons.support_agent,
            color: const Color(0xFFba1a1a),
            onTap: () => pushScreen(context, const CrmComplaintsScreen()),
          ),
          ModuleTile(
            title: 'Profile',
            icon: Icons.person,
            color: const Color(0xFF404752),
            onTap: () => pushScreen(context, const ProfileScreen()),
          ),
          if (isAdmin) ...[
            ModuleTile(
              title: 'Leave Admin',
              icon: Icons.event_available,
              color: const Color(0xFF006e1c),
              onTap: () => pushScreen(context, const AdminLeavesScreen()),
            ),
            ModuleTile(
              title: 'Expense Ledger',
              icon: Icons.account_balance_wallet,
              color: const Color(0xFF904d00),
              onTap: () => pushScreen(context, const AdminExpensesScreen()),
            ),
          ],
          if (role == 'super_admin' || role == 'admin')
            ModuleTile(
              title: 'User Management',
              icon: Icons.manage_accounts,
              color: const Color(0xFF0061a4),
              onTap: () => pushScreen(context, const IamUsersScreen()),
            ),
        ],
      ),
    );
  }
}
