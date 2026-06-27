// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/crm_service.dart';
import 'crm_lead_detail_screen.dart';

final followupsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(crmServiceProvider).getFollowupQueue();
});

class CrmFollowupsScreen extends ConsumerWidget {
  const CrmFollowupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followupsAsync = ref.watch(followupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow-up Queue'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
      ),
      body: followupsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No follow-ups scheduled'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(followupsProvider),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final f = items[i];
                final id = ApiParse.intField(f, ['id', 'ID']);
                final notes = ApiParse.field(f, ['notes', 'Notes']);
                final scheduled =
                    ApiParse.field(f, ['scheduled_for', 'ScheduledFor']);
                final leadId = ApiParse.intField(f, ['lead_id', 'LeadID']);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(notes.isEmpty ? 'Follow-up' : notes),
                    subtitle: Text('Scheduled: $scheduled'),
                    trailing: id == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            onPressed: () async {
                              final ctrl = TextEditingController();
                              await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Complete Follow-up'),
                                  content: DialogTextField(
                                    controller: ctrl,
                                    labelText: 'Outcome notes',
                                    maxLines: 3,
                                  ),
                                  actions: [
                                    DialogActionButtons(
                                      onCancel: () => Navigator.pop(ctx),
                                      submitText: 'Complete',
                                      onSubmit: ctrl.text.trim().isEmpty
                                          ? null
                                          : () async {
                                              Navigator.pop(ctx);
                                              try {
                                                await ref
                                                    .read(crmServiceProvider)
                                                    .completeFollowup(
                                                        id, ctrl.text.trim());
                                                ref.invalidate(followupsProvider);
                                                UiFeedback.success(
                                                    context, 'Follow-up done');
                                              } catch (e) {
                                                UiFeedback.parsedError(
                                                    context, e);
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                    onTap: leadId == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CrmLeadDetailScreen(leadId: leadId),
                              ),
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
          onRetry: () => ref.invalidate(followupsProvider),
        ),
      ),
    );
  }
}
