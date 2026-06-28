// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/providers/cache_provider.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/crm_service.dart';
import 'crm_lead_detail_screen.dart';

class CrmLeadsScreen extends ConsumerStatefulWidget {
  const CrmLeadsScreen({super.key});

  @override
  ConsumerState<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends ConsumerState<CrmLeadsScreen> {
  String filterStatus = 'all';
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
              DialogTextField(
                controller: nameController,
                labelText: 'Client Name',
              ),
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
                      clientEmail:
                          emailController.text.isEmpty ? null : emailController.text,
                      source: selectedSource,
                    );

                if (mounted) {
                  Navigator.pop(ctx);
                  await refreshLeadsCache(ref);
                  UiFeedback.success(context, 'Lead created successfully');
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

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(cachedLeadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CRM Leads'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
      ),
      body: leadsAsync.when(
        data: (leads) {
          final filteredLeads = filterStatus == 'all'
              ? leads
              : leads.where((lead) => lead['status'] == filterStatus).toList();

          return RefreshIndicator(
            onRefresh: () => refreshLeadsCache(ref),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildFilterChip('All', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('New', 'new'),
                        const SizedBox(width: 8),
                        _buildFilterChip('First Call', 'first_call'),
                        const SizedBox(width: 8),
                        _buildFilterChip('PDF Sent', 'pdf_sent'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Sample Sent', 'sample_sent'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Site Visit', 'site_visit'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Negotiation', 'negotiation'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Finalized', 'finalized'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Lost', 'lost'),
                      ],
                    ),
                  ),
                ),
                if (filteredLeads.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No leads found')),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) => _buildLeadCard(filteredLeads[index]),
                      childCount: filteredLeads.length,
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0061a4)),
        ),
        error: (err, _) => AsyncErrorView(
          error: err,
          onRetry: () => ref.invalidate(cachedLeadsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isCreatingLead ? null : _showCreateLeadDialog,
        backgroundColor: const Color(0xFF0061a4),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => filterStatus = status),
      selectedColor: const Color(0xFF0061a4),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }

  Widget _buildLeadCard(Map<String, dynamic> lead) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead['client_name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lead['client_phone'] ?? 'N/A',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(lead['status']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (lead['status'] ?? 'unknown')
                        .toString()
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (lead['client_email'] != null) ...[
              const SizedBox(height: 8),
              Text(
                lead['client_email'].toString(),
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    final id = int.tryParse('${lead['id']}');
                    if (id == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CrmLeadDetailScreen(leadId: id),
                      ),
                    );
                  },
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'new':
        return Colors.lightBlue;
      case 'first_call':
        return Colors.orange;
      case 'pdf_sent':
        return Colors.blue;
      case 'sample_sent':
        return Colors.purple;
      case 'site_visit':
        return Colors.teal;
      case 'negotiation':
        return Colors.amber;
      case 'finalized':
        return Colors.green;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
