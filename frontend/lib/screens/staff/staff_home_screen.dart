import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/ui_feedback.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/hr/services/hr_service.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/dialog_fields.dart';
import '../../shared/widgets/module_tile.dart';
import '../../features/hr/screens/my_attendance_screen.dart';
import '../../features/hr/screens/my_leaves_screen.dart';
import '../../features/hr/screens/my_expenses_screen.dart';

class StaffHomeScreen extends ConsumerStatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  ConsumerState<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends ConsumerState<StaffHomeScreen> {
  late Stream<DateTime> _clockStream;
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _clockStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  }

  void _handleCheckIn() async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(hrServiceProvider).checkIn();
      if (mounted) {
        UiFeedback.success(context, 'Checked in successfully!');
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _handleCheckOut() async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(hrServiceProvider).checkOut();
      if (mounted) {
        UiFeedback.success(context, 'Checked out successfully!');
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showOverrideModal() {
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;

    String formatTimeUI(TimeOfDay? time) {
      if (time == null) return '--:--';
      return time.format(context);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 24, left: 24, right: 24
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Off-site Pass', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF404752))),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: selectedStartTime ?? TimeOfDay.now(),
                                );
                                if (time != null) setModalState(() => selectedStartTime = time);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFbfc7d4)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(formatTimeUI(selectedStartTime), style: const TextStyle(fontSize: 16)),
                                    const Icon(Icons.schedule, size: 18, color: Color(0xFF707883)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF404752))),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: selectedEndTime ?? const TimeOfDay(hour: 19, minute: 0),
                                );
                                if (time != null) setModalState(() => selectedEndTime = time);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFbfc7d4)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(formatTimeUI(selectedEndTime), style: const TextStyle(fontSize: 16)),
                                    const Icon(Icons.schedule, size: 18, color: Color(0xFF707883)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DialogTextField(
                    controller: reasonController,
                    labelText: 'Reason (Optional)',
                    hintText: 'Outside for official work',
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: 'Submit Request',
                    isLoading: isSubmitting,
                    onPressed: () async {
                      setModalState(() => isSubmitting = true);
                      try {
                        // Include the time details if they exist in the reason since the API only takes reason for offline queues right now.
                        // Wait, my HrService `submitOverrideRequest` only takes a string reason.
                        final fullReason = "From ${formatTimeUI(selectedStartTime)} to ${formatTimeUI(selectedEndTime)}: ${reasonController.text.trim()}";
                        await ref.read(hrServiceProvider).submitOverrideRequest(fullReason);
                        if (mounted) {
                          Navigator.pop(context); // Close modal
                          UiFeedback.success(
                            context,
                            'Request submitted! Pending admin approval.',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          UiFeedback.parsedError(context, e);
                        }
                        setModalState(() => isSubmitting = false);
                      }
                    },
                  ),
                ],
              ),
            );
          }
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.userRole ?? 'Member';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio CRM', style: TextStyle(color: Color(0xFF0061a4), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF707883)),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Banner
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: const Color(0xFF2196f3),
                      child: Text(role.isNotEmpty ? role[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome back!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        Text('${role[0].toUpperCase()}${role.substring(1)}', style: const TextStyle(color: Color(0xFF707883))),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time & Action Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Text('CURRENT TIME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: Color(0xFF404752))),
                    const SizedBox(height: 8),
                    StreamBuilder<DateTime>(
                        stream: _clockStream,
                        builder: (context, snapshot) {
                          final now = snapshot.data ?? DateTime.now();
                          return Column(
                            children: [
                              Text(DateFormat('hh:mm a').format(now), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -1)),
                              Text(DateFormat('MMM dd, yyyy').format(now), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF0061a4))),
                            ],
                          );
                        }
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isActionLoading ? null : _handleCheckIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Check-In', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006e1c),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isActionLoading ? null : _handleCheckOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('Check-Out', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFba1a1a),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _showOverrideModal,
                      child: const Text('Working off-site or left early?', style: TextStyle(color: Color(0xFF0061a4), decoration: TextDecoration.underline)),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('Quick Links', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF404752))),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.7,
              children: [
                ModuleTile(
                  title: 'My Attendance',
                  icon: Icons.access_time,
                  color: const Color(0xFF0061a4),
                  onTap: () => pushScreen(context, const MyAttendanceScreen()),
                ),
                ModuleTile(
                  title: 'My Leaves',
                  icon: Icons.event_note,
                  color: const Color(0xFF006e1c),
                  onTap: () => pushScreen(context, const MyLeavesScreen()),
                ),
                ModuleTile(
                  title: 'My Expenses',
                  icon: Icons.receipt_long,
                  color: const Color(0xFF904d00),
                  onTap: () => pushScreen(context, const MyExpensesScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}