import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/module_tile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../iam/screens/profile_screen.dart';
import '../services/hr_service.dart';
import 'my_attendance_screen.dart';
import 'my_leaves_screen.dart';
import 'my_expenses_screen.dart';
import 'admin_leaves_screen.dart';
import 'admin_expenses_screen.dart';
import '../../iam/screens/iam_users_screen.dart';

class HrHubScreen extends ConsumerStatefulWidget {
  const HrHubScreen({super.key});

  @override
  ConsumerState<HrHubScreen> createState() => _HrHubScreenState();
}

class _HrHubScreenState extends ConsumerState<HrHubScreen> {
  bool _isProcessing = false;

  Future<void> _handleCheckAction(bool checkingIn) async {
    setState(() => _isProcessing = true);
    try {
      final svc = ref.read(hrServiceProvider);
      if (checkingIn) {
        await svc.checkIn();
      } else {
        await svc.checkOut();
      }
      if (mounted) {
        UiFeedback.success(context, checkingIn ? 'Checked in successfully' : 'Checked out successfully');
      }
    } catch (e) {
      if (mounted) UiFeedback.parsedError(context, e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).userRole;
    final isAdmin = role == 'admin' || role == 'super_admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero check-in/out card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  Text('Attendance', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _CheckActionButton(
                          label: 'Check In',
                          icon: Icons.login,
                          color: AppColors.primary,
                          onTap: _isProcessing ? null : () => _handleCheckAction(true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _CheckActionButton(
                          label: 'Check Out',
                          icon: Icons.logout,
                          color: AppColors.error,
                          onTap: _isProcessing ? null : () => _handleCheckAction(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                ModuleTile(
                  title: 'My Attendance',
                  icon: Icons.access_time,
                  color: AppColors.primary,
                  onTap: () => pushScreen(context, const MyAttendanceScreen()),
                ),
                ModuleTile(
                  title: 'My Leaves',
                  icon: Icons.beach_access,
                  color: AppColors.tertiary,
                  onTap: () => pushScreen(context, const MyLeavesScreen()),
                ),
                ModuleTile(
                  title: 'My Expenses',
                  icon: Icons.receipt_long,
                  color: AppColors.secondary,
                  onTap: () => pushScreen(context, const MyExpensesScreen()),
                ),
                if (isAdmin) ...[
                  ModuleTile(
                    title: 'Leave Admin',
                    icon: Icons.event_available,
                    color: AppColors.primary,
                    onTap: () => pushScreen(context, const AdminLeavesScreen()),
                  ),
                  ModuleTile(
                    title: 'Expense Ledger',
                    icon: Icons.account_balance_wallet,
                    color: AppColors.tertiary,
                    onTap: () => pushScreen(context, const AdminExpensesScreen()),
                  ),
                  ModuleTile(
                    title: 'User Management',
                    icon: Icons.manage_accounts,
                    color: AppColors.secondary,
                    onTap: () => pushScreen(context, const IamUsersScreen()),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CheckActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
