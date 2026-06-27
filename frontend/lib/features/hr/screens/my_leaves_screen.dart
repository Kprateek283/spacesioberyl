// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../services/hr_service.dart';

// Riverpod provider for HR leaves
final myLeavesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final cached = await DatabaseHelper.instance.getCachedLeaves();
  return _normalizeLeavesPayload(cached);
});

class MyLeavesScreen extends ConsumerStatefulWidget {
  const MyLeavesScreen({super.key});

  @override
  ConsumerState<MyLeavesScreen> createState() => _MyLeavesScreenState();
}

class _MyLeavesScreenState extends ConsumerState<MyLeavesScreen> {
  bool isCreatingLeave = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _refreshLeavesCache();
      if (mounted) {
        // ignore: unused_result
        ref.refresh(myLeavesProvider);
      }
    });
  }

  Future<void> _showCreateLeaveDialog() async {
    DateTime? startDate;
    DateTime? endDate;
    final reasonController = TextEditingController();

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Leave'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => startDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        startDate != null
                            ? DateFormat('MMM dd, yyyy').format(startDate!)
                            : 'Start Date',
                      ),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: startDate ?? DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => endDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        endDate != null
                            ? DateFormat('MMM dd, yyyy').format(endDate!)
                            : 'End Date',
                      ),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g., Personal, Medical, etc.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            isSubmitting: isCreatingLeave,
            submitText: 'Request',
            onSubmit: () async {
              // Validate dates
              if (startDate == null) {
                UiFeedback.error(context, 'Start date is required');
                return;
              }

              if (endDate == null) {
                UiFeedback.error(context, 'End date is required');
                return;
              }

              final dateRangeError = FormValidators.validateDateRange(startDate, endDate);
              if (dateRangeError != null) {
                UiFeedback.error(context, dateRangeError);
                return;
              }

              // Validate reason
              final reasonError = FormValidators.validateRequired(
                reasonController.text,
                'Reason',
              );
              if (reasonError != null) {
                UiFeedback.error(context, reasonError);
                return;
              }

              try {
                setState(() => isCreatingLeave = true);
                await ref.read(hrServiceProvider).requestLeave(
                      leaveType: 'casual_leave',
                      startDate: DateFormat('yyyy-MM-dd').format(startDate!),
                      endDate: DateFormat('yyyy-MM-dd').format(endDate!),
                      reason: reasonController.text.trim(),
                    );
                await _refreshLeavesCache();
                Navigator.pop(ctx);
                // ignore: unused_result
                ref.refresh(myLeavesProvider);
                if (mounted) {
                  UiFeedback.success(context, 'Leave request submitted');
                }
              } catch (e) {
                if (mounted) {
                  UiFeedback.parsedError(context, e);
                }
              } finally {
                setState(() => isCreatingLeave = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _cancelLeaveRequest(String leaveId) async {
    final parsedLeaveId = int.tryParse(leaveId);
    if (parsedLeaveId == null) return;

    try {
      setState(() => isCreatingLeave = true);
      await ref.read(hrServiceProvider).cancelLeave(parsedLeaveId);
      await _refreshLeavesCache();
      // ignore: unused_result
      ref.refresh(myLeavesProvider);
      if (mounted) {
        UiFeedback.success(context, 'Leave request cancelled');
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    } finally {
      setState(() => isCreatingLeave = false);
    }
  }

  Future<void> _refreshLeavesCache() async {
    final data = await ref.read(hrServiceProvider).getMyLeaves();
    if (data is List) {
      await DatabaseHelper.instance.cacheLeaves(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leavesAsync = ref.watch(myLeavesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Leaves'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: leavesAsync.when(
        data: (leaves) {
          final balance = leaves['balance'] as Map<String, dynamic>;
          final requests = leaves['requests'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
            child: Column(
              children: [
                // Leave Balance Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0061a4),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Balance',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildBalanceItem(
                            'Total',
                            '${balance['total']}',
                            Colors.white,
                          ),
                          _buildBalanceItem(
                            'Used',
                            '${balance['used']}',
                            Colors.red[200]!,
                          ),
                          _buildBalanceItem(
                            'Available',
                            '${balance['available']}',
                            Colors.green[200]!,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Leave Requests
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leave Requests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (requests.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No leave requests yet'),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: requests.length,
                          itemBuilder: (ctx, index) {
                            final request = requests[index] as Map<String, dynamic>;
                            return _buildLeaveRequestCard(request);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0061a4)),
        ),
        error: (err, stack) => AsyncErrorView(
          error: err,
          onRetry: () => ref.invalidate(myLeavesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isCreatingLeave ? null : _showCreateLeaveDialog,
        backgroundColor: const Color(0xFF0061a4),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String? ?? 'pending';
    final startDate = request['start_date'] as String?;
    final endDate = request['end_date'] as String?;
    final reason = request['reason'] as String?;
    final id = request['id']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$startDate to $endDate',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason ?? 'No reason provided',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            if (status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton(
                  onPressed: () => _cancelLeaveRequest(id ?? ''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 36),
                  ),
                  child: const Text('Cancel Request'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

Map<String, dynamic> _normalizeLeavesPayload(dynamic data) {
  final fallback = <String, dynamic>{
    'balance': {
      'total': 20,
      'used': 0,
      'available': 20,
    },
    'requests': <Map<String, dynamic>>[],
  };

  if (data is List) {
    final requests = data
        .whereType<Map>()
        .map(
          (item) => <String, dynamic>{
            'id': item['id']?.toString() ?? '',
            'start_date': item['start_date']?.toString() ?? '',
            'end_date': item['end_date']?.toString() ?? '',
            'reason': item['reason']?.toString() ?? '',
            'status': item['status']?.toString() ?? 'pending',
            'leave_type': item['leave_type']?.toString() ?? '',
          },
        )
        .toList();

    final used = requests
        .where((r) => r['status'] == 'approved')
        .length;
    final total = 20;
    return {
      'balance': {
        'total': total,
        'used': used,
        'available': total - used,
      },
      'requests': requests,
    };
  }

  if (data is! Map<String, dynamic>) {
    return fallback;
  }

  final balanceRaw = data['balance'];
  final requestsRaw = data['requests'] ?? data['leaves'] ?? data['items'];

  final balance = <String, dynamic>{
    'total': (balanceRaw is Map ? balanceRaw['total'] : 20) ?? 20,
    'used': (balanceRaw is Map ? balanceRaw['used'] : 0) ?? 0,
    'available': (balanceRaw is Map ? balanceRaw['available'] : 20) ?? 20,
  };

  final requests = (requestsRaw is List)
      ? requestsRaw
          .whereType<Map>()
          .map(
            (item) => <String, dynamic>{
              'id': item['id']?.toString() ?? '',
              'start_date': item['start_date']?.toString() ?? '',
              'end_date': item['end_date']?.toString() ?? '',
              'reason': item['reason']?.toString() ?? '',
              'status': item['status']?.toString() ?? 'pending',
            },
          )
          .toList()
      : <Map<String, dynamic>>[];

  return {
    'balance': balance,
    'requests': requests,
  };
}
