// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/hr_service.dart';

final adminLeavesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, status) {
  return ref.watch(hrServiceProvider).getAllLeaves(status: status);
});

class AdminLeavesScreen extends ConsumerStatefulWidget {
  const AdminLeavesScreen({super.key});

  @override
  ConsumerState<AdminLeavesScreen> createState() => _AdminLeavesScreenState();
}

class _AdminLeavesScreenState extends ConsumerState<AdminLeavesScreen> {
  String _filter = 'pending';

  Future<void> _processLeave(Map<String, dynamic> leave, String status) async {
    final remarksCtrl = TextEditingController();
    final id = ApiParse.intField(leave, ['id', 'ID']);
    if (id == null) return;

    if (status == 'rejected') {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Leave'),
          content: DialogTextField(
            controller: remarksCtrl,
            labelText: 'Reason (required)',
            maxLines: 3,
          ),
          actions: [
            DialogActionButtons(
              onCancel: () => Navigator.pop(ctx),
              submitText: 'Reject',
              onSubmit: remarksCtrl.text.trim().isEmpty
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _submit(id, status, remarksCtrl.text.trim());
                    },
            ),
          ],
        ),
      );
    } else {
      await _submit(id, status, 'Approved');
    }
  }

  Future<void> _submit(int id, String status, String remarks) async {
    try {
      await ref.read(hrServiceProvider).updateLeaveStatus(id, status, remarks);
      ref.invalidate(adminLeavesProvider);
      if (mounted) UiFeedback.success(context, 'Leave $status');
    } catch (e) {
      if (mounted) UiFeedback.parsedError(context, e);
    }
  }

  String _fmt(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leavesAsync = ref.watch(adminLeavesProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: ['pending', 'approved', 'rejected'].map((s) {
                final selected = _filter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(s[0].toUpperCase() + s.substring(1)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = s),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: leavesAsync.when(
        data: (leaves) {
          if (leaves.isEmpty) {
            return const Center(child: Text('No leave requests'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminLeavesProvider(_filter)),
            child: ListView.builder(
              itemCount: leaves.length,
              itemBuilder: (_, i) {
                final l = leaves[i];
                final type =
                    ApiParse.field(l, ['leave_type', 'LeaveType'], fallback: '-');
                final reason =
                    ApiParse.field(l, ['reason', 'Reason'], fallback: '-');
                final start =
                    ApiParse.field(l, ['start_date', 'StartDate']);
                final end = ApiParse.field(l, ['end_date', 'EndDate']);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_fmt(start)} → ${_fmt(end)}'),
                        const SizedBox(height: 8),
                        Text(reason),
                        if (_filter == 'pending') ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _processLeave(l, 'rejected'),
                                child: const Text('Reject',
                                    style: TextStyle(color: Colors.red)),
                              ),
                              ElevatedButton(
                                onPressed: () => _processLeave(l, 'approved'),
                                child: const Text('Approve'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          error: e,
          onRetry: () => ref.invalidate(adminLeavesProvider(_filter)),
        ),
            ),
          ),
        ],
      ),
    );
  }
}
