import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/ui_feedback.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/iam/screens/iam_users_screen.dart';
import '../../features/hr/services/hr_service.dart';
import '../../shared/widgets/dialog_action_buttons.dart';
import '../../shared/widgets/dialog_fields.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _reportData = [];
  List<dynamic> _pendingList = []; // Added to store raw pending requests

  // Summary Metrics
  int _presentCount = 0;
  int _absentCount = 0;
  int _overrideCount = 0;
  int _offsiteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final hrService = ref.read(hrServiceProvider);
      final results = await Future.wait([
        hrService.getDailyReport(),
        hrService.getPendingOverrides(),
      ]);

      final report = results[0] as List<dynamic>;
      final pending = results[1] as List<dynamic>;

      // Calculate summary metrics
      int present = 0, absent = 0, overrides = 0, offsite = 0;
      for (var user in report) {
        switch ((user['status'] ?? '').toString().toLowerCase()) {
          case 'present':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          case 'pending_override':
            overrides++;
            break;
          case 'off_site':
            offsite++;
            break;
        }
      }

      if (mounted) {
        setState(() {
          _reportData = report;
          _pendingList = pending;
          _presentCount = present;
          _absentCount = absent;
          _overrideCount = overrides;
          _offsiteCount = offsite;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleApprove(String overrideId) async {
    try {
      await ref.read(hrServiceProvider).reviewOverride(overrideId, 'approved');
      _loadDashboardData();
      if (mounted) {
        UiFeedback.success(context, 'Override approved successfully');
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    }
  }

  void _showRejectModal(String overrideId) {
    final reasonController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  title: const Text('Reject Request', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Please provide a mandatory reason for rejecting this request.'),
                      const SizedBox(height: 16),
                      DialogTextField(
                        controller: reasonController,
                        labelText: 'Reason for rejection',
                        onChanged: (val) => setModalState(() {}),
                      ),
                    ],
                  ),
                  actions: [
                    DialogActionButtons(
                      onCancel: () => Navigator.pop(context),
                      submitText: 'CONFIRM REJECT',
                      onSubmit: reasonController.text.trim().isEmpty
                          ? null
                          : () async {
                              Navigator.pop(context);
                              try {
                                await ref
                                    .read(hrServiceProvider)
                                    .reviewOverride(
                                      overrideId,
                                      'rejected',
                                      adminFeedback: reasonController.text.trim(),
                                    );
                                _loadDashboardData();
                                if (mounted) {
                                  UiFeedback.success(
                                    context,
                                    'Override rejected successfully',
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  UiFeedback.parsedError(context, e);
                                }
                              }
                            },
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('hh:mm a').format(date);
    } catch (e) {
      return '--:--';
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown Date';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    // We wrap the Scaffold in a DefaultTabController to get tabs!
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFEF9F2),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('Team Dashboard', style: TextStyle(color: Color(0xFF0061a4), fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF707883)),
              onPressed: _loadDashboardData,
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Color(0xFF707883)),
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
            )
          ],
          bottom: const TabBar(
            labelColor: Color(0xFF0061a4),
            unselectedLabelColor: Color(0xFF707883),
            indicatorColor: Color(0xFF0061a4),
            tabs: [
              Tab(text: "Today's Report"),
              Tab(text: "Pending Requests"),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IamUsersScreen()),
            );
          },
          backgroundColor: const Color(0xFF0061a4),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add),
          label: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildDailyReportTab(),
            _buildPendingRequestsTab(),
          ],
        ),
      ),
    );
  }

  // =========================================
  // TAB 1: DAILY REPORT
  // =========================================
  Widget _buildDailyReportTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Real-time attendance and operational status', style: TextStyle(color: Color(0xFF404752))),
            const SizedBox(height: 24),

            // Bento Grid Summary Cards
            Row(
              children: [
                _buildSummaryCard('Present', _presentCount.toString(), Icons.check_circle, const Color(0xFF006e1c), const Color(0xFF94f990).withOpacity(0.2)),
                const SizedBox(width: 16),
                _buildSummaryCard('Overrides', _overrideCount.toString(), Icons.pending_actions, const Color(0xFF904d00), const Color(0xFFffdcc2).withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSummaryCard('Off-site', _offsiteCount.toString(), Icons.directions_car, const Color(0xFF0061a4), const Color(0xFFd1e4ff).withOpacity(0.4)),
                const SizedBox(width: 16),
                _buildSummaryCard('Absent', _absentCount.toString(), Icons.cancel, const Color(0xFFba1a1a), const Color(0xFFffdad6).withOpacity(0.4)),
              ],
            ),
            const SizedBox(height: 32),

            // The Master List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFe5e8f0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reportData.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFe5e8f0)),
                itemBuilder: (context, index) {
                  return _buildEmployeeRow(_reportData[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================
  // TAB 2: PENDING INBOX
  // =========================================
  Widget _buildPendingRequestsTab() {
    if (_pendingList.isEmpty) {
      return const Center(
        child: Text('All caught up! No pending requests.', style: TextStyle(color: Color(0xFF707883), fontSize: 16)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _pendingList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final request = _pendingList[index];
          // Safely extract JSON keys regardless of Go struct capitalizations
          final id = request['ID'] ?? request['id'];
          final date = request['AttendanceDate'] ??
              request['attendance_date'] ??
              request['date'];
          final start = request['RequestedStartTime'] ??
              request['requested_start_time'] ??
              request['check_in_time'];
          final end = request['RequestedEndTime'] ??
              request['requested_end_time'] ??
              request['check_out_time'];
          final reason = request['EmployeeReason'] ??
              request['employee_reason'] ??
              request['override_reason'];

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFffdcc2)),
              boxShadow: [BoxShadow(color: const Color(0xFF904d00).withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Requested for: ${_formatDate(date)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Icon(Icons.pending_actions, color: Color(0xFF904d00)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Color(0xFF707883)),
                    const SizedBox(width: 8),
                    Text('$start - $end', style: const TextStyle(color: Color(0xFF404752))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 16, color: Color(0xFF707883)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(reason ?? 'No reason provided', style: const TextStyle(color: Color(0xFF404752)))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showRejectModal(id.toString()),
                      icon: const Icon(Icons.close, color: Color(0xFFba1a1a)),
                      label: const Text('Reject', style: TextStyle(color: Color(0xFFba1a1a))),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFffdad6))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _handleApprove(id.toString()),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006e1c), foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================================
  // HELPER WIDGETS
  // =========================================
  Widget _buildSummaryCard(String title, String count, IconData icon, Color mainColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: mainColor.withOpacity(0.1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: mainColor, size: 20),
                const SizedBox(width: 8),
                Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mainColor)),
              ],
            ),
            const SizedBox(height: 12),
            Text(count, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> user) {
    final rawStatus = (user['status'] ?? '').toString().toLowerCase();
    final status = _formatStatus(rawStatus);
    final username = (user['username'] ??
            user['name'] ??
            'User #${user['user_id'] ?? user['id'] ?? ''}')
        .toString();

    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (rawStatus) {
      case 'present':
        statusColor = const Color(0xFF006e1c);
        statusBg = const Color(0xFF91f78e).withOpacity(0.4);
        statusIcon = Icons.check_circle;
        break;
      case 'pending_override':
        statusColor = const Color(0xFF904d00);
        statusBg = const Color(0xFFffdcc2);
        statusIcon = Icons.error;
        break;
      case 'off_site':
        statusColor = const Color(0xFF0061a4);
        statusBg = const Color(0xFFd1e4ff);
        statusIcon = Icons.flight_takeoff;
        break;
      default: // Absent
        statusColor = const Color(0xFFba1a1a);
        statusBg = const Color(0xFFffdad6);
        statusIcon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: const Color(0xFFe5e8f0), child: Text(username[0].toUpperCase(), style: const TextStyle(color: Color(0xFF404752)))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, decoration: rawStatus == 'absent' ? TextDecoration.lineThrough : null, color: rawStatus == 'absent' ? const Color(0xFF707883) : Colors.black)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rawStatus == 'present')
            Row(
              children: [
                const Icon(Icons.login, size: 16, color: Color(0xFF707883)),
                const SizedBox(width: 4),
                Text(_formatTime(user['check_in_time']), style: const TextStyle(color: Color(0xFF404752))),
                const SizedBox(width: 16),
                const Icon(Icons.logout, size: 16, color: Color(0xFF707883)),
                const SizedBox(width: 4),
                Text(_formatTime(user['check_out_time']), style: const TextStyle(color: Color(0xFF404752))),
              ],
            )
          else if (user['reason'] != null && user['reason'].toString().isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF707883)),
                const SizedBox(width: 4),
                Expanded(child: Text('"${user['reason']}"', style: const TextStyle(color: Color(0xFF404752), fontStyle: FontStyle.italic))),
              ],
            )
          else
            const Text('No schedule data', style: TextStyle(color: Color(0xFF707883), fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending_override':
        return 'Pending Override';
      case 'off_site':
        return 'Off-site';
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'half_day':
        return 'Half Day';
      default:
        return status.replaceAll('_', ' ').trim();
    }
  }
}