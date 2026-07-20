import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/cache_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/crm_service.dart';
import 'crm_lead_detail_screen.dart';
import 'crm_followups_screen.dart';
import 'crm_complaints_screen.dart';

/// The five backend-supported statuses grouped as (near-)terminal for
/// visual weight, plus the four intermediate mid-pipeline stages.
const _kanbanColumns = [
  ('new', 'New'),
  ('first_call', 'First Call'),
  ('pdf_sent', 'PDF Sent'),
  ('sample_sent', 'Sample Sent'),
  ('site_visit', 'Site Visit'),
  ('negotiation', 'Negotiation'),
  ('finalized', 'Finalized'),
  ('lost', 'Lost'),
];

class CrmLeadsScreen extends ConsumerStatefulWidget {
  const CrmLeadsScreen({super.key});

  @override
  ConsumerState<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends ConsumerState<CrmLeadsScreen> {
  bool isCreatingLead = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await refreshLeadsCache(ref);
      } catch (e) {
        if (mounted) UiFeedback.parsedError(context, e);
      }
    });
  }

  Future<void> _showCreateLeadDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String selectedSource = 'walk_in';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Lead'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogTextField(controller: nameController, labelText: 'Client Name'),
              const SizedBox(height: 12),
              DialogTextField(
                controller: phoneController,
                labelText: 'Phone Number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: emailController,
                labelText: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DialogDropdownField<String>(
                value: selectedSource,
                items: const [
                  DropdownMenuItem(value: 'walk_in', child: Text('Walk In')),
                  DropdownMenuItem(value: 'referral', child: Text('Referral')),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                ],
                onChanged: (value) {
                  if (value != null) selectedSource = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            isSubmitting: isCreatingLead,
            submitText: 'Create',
            onSubmit: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                UiFeedback.error(context, 'Name and phone are required');
                return;
              }
              try {
                setState(() => isCreatingLead = true);
                await ref.read(crmServiceProvider).createLead(
                      clientName: nameController.text,
                      clientPhone: phoneController.text,
                      clientEmail: emailController.text.isEmpty ? null : emailController.text,
                      source: selectedSource,
                    );
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.pop(ctx);
                  await refreshLeadsCache(ref);
                  if (mounted) UiFeedback.success(context, 'Lead created successfully');
                }
              } catch (e) {
                if (mounted) UiFeedback.parsedError(context, e);
              } finally {
                if (mounted) setState(() => isCreatingLead = false);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _moveLeadToStatus(Map<String, dynamic> lead, String newStatus) async {
    final id = int.tryParse('${lead['id']}');
    if (id == null || lead['status'] == newStatus) return;

    String? lostReason;
    if (newStatus == 'lost') {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mark Lead as Lost'),
          content: DialogTextField(
            controller: reasonController,
            labelText: 'Reason',
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      );
      if (confirmed != true || reasonController.text.trim().isEmpty) return;
      lostReason = reasonController.text.trim();
    }

    try {
      await ref.read(crmServiceProvider).updateLeadStatus(id, newStatus, lostReason: lostReason);
      if (mounted) UiFeedback.success(context, 'Lead moved to ${newStatus.replaceAll('_', ' ')}');
    } catch (e) {
      if (mounted) UiFeedback.parsedError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(cachedLeadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Pipeline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_callback),
            tooltip: 'Follow-ups',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CrmFollowupsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.support_agent),
            tooltip: 'Complaints',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CrmComplaintsScreen()),
            ),
          ),
        ],
      ),
      body: leadsAsync.when(
        data: (leads) => RefreshIndicator(
          onRefresh: () => refreshLeadsCache(ref),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _kanbanColumns.map((col) {
                final (statusKey, label) = col;
                final columnLeads = leads.where((l) => l['status'] == statusKey).toList();
                return _KanbanColumn(
                  statusKey: statusKey,
                  label: label,
                  leads: columnLeads,
                  onLeadDropped: _moveLeadToStatus,
                  onCardTap: (lead) {
                    final id = int.tryParse('${lead['id']}');
                    if (id == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CrmLeadDetailScreen(leadId: id)),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AsyncErrorView(
          error: err,
          onRetry: () => ref.invalidate(cachedLeadsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isCreatingLead ? null : _showCreateLeadDialog,
        tooltip: 'Add Lead',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String statusKey;
  final String label;
  final List<Map<String, dynamic>> leads;
  final void Function(Map<String, dynamic> lead, String newStatus) onLeadDropped;
  final void Function(Map<String, dynamic> lead) onCardTap;

  const _KanbanColumn({
    required this.statusKey,
    required this.label,
    required this.leads,
    required this.onLeadDropped,
    required this.onCardTap,
  });

  Color get _accentColor {
    if (statusKey == 'finalized') return AppColors.primary;
    if (statusKey == 'lost') return AppColors.error;
    return AppColors.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (details) => onLeadDropped(details.data, statusKey),
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          return Container(
            width: 280,
            decoration: BoxDecoration(
              color: isHovering ? AppColors.surfaceContainerLow : AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: isHovering ? Border.all(color: AppColors.primary, width: 2) : null,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: _accentColor, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(999)),
                        child: Text('${leads.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Column(
                    children: leads.map((lead) {
                      return Draggable<Map<String, dynamic>>(
                        data: lead,
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(width: 260, child: _LeadCard(lead: lead, onTap: () {})),
                        ),
                        childWhenDragging: Opacity(opacity: 0.3, child: _LeadCard(lead: lead, onTap: () {})),
                        child: _LeadCard(lead: lead, onTap: () => onCardTap(lead)),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Map<String, dynamic> lead;
  final VoidCallback onTap;

  const _LeadCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final source = (lead['source'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead['client_name'] ?? 'Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                lead['client_phone'] ?? 'N/A',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
              ),
              if (source.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    source.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.onSecondaryContainer),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
