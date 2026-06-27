// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/crm_service.dart';

final complaintsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(crmServiceProvider).getComplaints();
});

class CrmComplaintsScreen extends ConsumerStatefulWidget {
  const CrmComplaintsScreen({super.key});

  @override
  ConsumerState<CrmComplaintsScreen> createState() =>
      _CrmComplaintsScreenState();
}

class _CrmComplaintsScreenState extends ConsumerState<CrmComplaintsScreen> {
  bool _creating = false;

  Future<void> _showCreateDialog() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var priority = 'medium';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: const Text('New Complaint'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DialogTextField(controller: titleCtrl, labelText: 'Title'),
                const SizedBox(height: 12),
                DialogTextField(
                  controller: descCtrl,
                  labelText: 'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DialogDropdownField<String>(
                  value: priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (v) => setModal(() => priority = v ?? priority),
                ),
              ],
            ),
          ),
          actions: [
            DialogActionButtons(
              onCancel: () => Navigator.pop(ctx),
              isSubmitting: _creating,
              submitText: 'Submit',
              onSubmit: () async {
                if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) {
                  UiFeedback.error(context, 'Title and description required');
                  return;
                }
                setModal(() => _creating = true);
                try {
                  await ref.read(crmServiceProvider).createComplaint(
                        title: titleCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        priority: priority,
                      );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(complaintsProvider);
                    UiFeedback.success(context, 'Complaint filed');
                  }
                } catch (e) {
                  UiFeedback.parsedError(context, e);
                } finally {
                  setModal(() => _creating = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final complaintsAsync = ref.watch(complaintsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Complaints'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: const Color(0xFF0061a4),
        child: const Icon(Icons.add),
      ),
      body: complaintsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No complaints'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(complaintsProvider),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final c = items[i];
                final id = ApiParse.intField(c, ['id', 'ID']);
                final title = ApiParse.field(c, ['title', 'Title']);
                final status = ApiParse.field(c, ['status', 'Status'],
                    fallback: 'open');
                final priority = ApiParse.field(c, ['priority', 'Priority']);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(title),
                    subtitle: Text('$priority · $status'),
                    trailing: status == 'resolved' || id == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.done_all, color: Colors.green),
                            onPressed: () async {
                              try {
                                await ref
                                    .read(crmServiceProvider)
                                    .resolveComplaint(id);
                                ref.invalidate(complaintsProvider);
                                UiFeedback.success(context, 'Resolved');
                              } catch (e) {
                                UiFeedback.parsedError(context, e);
                              }
                            },
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
          onRetry: () => ref.invalidate(complaintsProvider),
        ),
      ),
    );
  }
}
