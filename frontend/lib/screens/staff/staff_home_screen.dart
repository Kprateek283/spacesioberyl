import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import '../../services/hr_service.dart';

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  final _authService = AuthService();
  final _hrService = HrService(); // <-- Added HR Service

  Map<String, dynamic>? _userData;
  late Stream<DateTime> _clockStream;

  bool _isActionLoading = false; // Prevents spam-clicking

  @override
  void initState() {
    super.initState();
    _clockStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
    _loadUserData();
  }

  void _loadUserData() async {
    final data = await _authService.getSavedUserData();
    if (data == null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    setState(() => _userData = data);
  }

  // --- NEW: Check-In Handler ---
  void _handleCheckIn() async {
    setState(() => _isActionLoading = true);
    try {
      await _hrService.checkIn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully!'), backgroundColor: Color(0xFF006e1c)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFba1a1a)),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // --- NEW: Check-Out Handler ---
  void _handleCheckOut() async {
    setState(() => _isActionLoading = true);
    try {
      await _hrService.checkOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out successfully!'), backgroundColor: Color(0xFF006e1c)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFba1a1a)),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  // --- UPDATED: Override Modal ---
// --- UPDATED: Override Modal with Time Pickers ---
  void _showOverrideModal() {
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;

    // Helper to format TimeOfDay to the backend's required HH:mm:ss format
    String? formatTime(TimeOfDay? time) {
      if (time == null) return null;
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      return DateFormat('HH:mm:ss').format(dt); // 24-hour format
    }

    // Helper to format TimeOfDay for the UI (12-hour AM/PM)
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

                  // Time Pickers Row
                  Row(
                    children: [
                      // Start Time Column
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
                      // End Time Column
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

                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason (Optional)',
                      hintText: 'Outside for official work',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF0061a4), width: 2)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        setModalState(() => isSubmitting = true);
                        try {
                          await _hrService.submitOverride(
                            reason: reasonController.text.trim(),
                            startTime: formatTime(selectedStartTime), // Send formatted time
                            endTime: formatTime(selectedEndTime),     // Send formatted time
                          );
                          if (mounted) {
                            Navigator.pop(context); // Close modal
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Request submitted! Pending admin approval.'), backgroundColor: Color(0xFF006e1c)),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: const Color(0xFFba1a1a)),
                            );
                          }
                          setModalState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0061a4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Submit Request'),
                    ),
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
    if (_userData == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final username = _userData?['username'] ?? 'User';
    final dept = _userData?['department_name'] ?? 'Staff';
    final role = _userData?['role_name'] ?? 'Member';

    return Scaffold(
      backgroundColor: const Color(0xFFFEF9F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Studio CRM', style: TextStyle(color: Color(0xFF0061a4), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF707883)),
            onPressed: () async {
              await _authService.logout();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFe5e8f0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFF2196f3),
                    child: Text(username[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back, ${username[0].toUpperCase()}${username.substring(1)}!',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      Text('${role[0].toUpperCase()}${role.substring(1)} | ${dept[0].toUpperCase()}${dept.substring(1)} Dept',
                          style: const TextStyle(color: Color(0xFF707883))),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Time & Action Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFe5e8f0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  const Text('CURRENT TIME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: Color(0xFF404752))),
                  const SizedBox(height: 8),

                  // Live Clock
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

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActionLoading ? null : _handleCheckIn, // Wired Up
                          icon: const Icon(Icons.login),
                          label: const Text('Check-In', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006e1c),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isActionLoading ? null : _handleCheckOut, // Wired Up
                          icon: const Icon(Icons.logout),
                          label: const Text('Check-Out', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFba1a1a), // Red for checkout
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Override Link
                  TextButton(
                    onPressed: _showOverrideModal,
                    child: const Text('Working off-site or left early?', style: TextStyle(color: Color(0xFF0061a4), decoration: TextDecoration.underline)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}