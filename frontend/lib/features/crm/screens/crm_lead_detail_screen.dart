import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/crm_service.dart';
import 'quotation_builder_screen.dart';

class CrmLeadDetailScreen extends ConsumerStatefulWidget {
  final int leadId;

  const CrmLeadDetailScreen({super.key, required this.leadId});

  @override
  ConsumerState<CrmLeadDetailScreen> createState() =>
      _CrmLeadDetailScreenState();
}

class _CrmLeadDetailScreenState extends ConsumerState<CrmLeadDetailScreen> {
  Map<String, dynamic>? _lead;
  List<Map<String, dynamic>> _quotations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(crmServiceProvider);
      final lead = await svc.getLead(widget.leadId);
      final quotes = await svc.getQuotations(widget.leadId);
      if (mounted) {
        setState(() {
          _lead = lead;
          _quotations = quotes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        UiFeedback.parsedError(context, e);
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      if (status == 'lost') {
        final reasonCtrl = TextEditingController();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mark Lost'),
            content: DialogTextField(
              controller: reasonCtrl,
              labelText: 'Lost reason',
            ),
            actions: [
              DialogActionButtons(
                onCancel: () => Navigator.pop(ctx),
                submitText: 'Confirm',
                onSubmit: reasonCtrl.text.trim().isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await ref.read(crmServiceProvider).updateLeadStatus(
                              widget.leadId,
                              'lost',
                              lostReason: reasonCtrl.text.trim(),
                            );
                        await _load();
                      },
              ),
            ],
          ),
        );
      } else {
        await ref
            .read(crmServiceProvider)
            .updateLeadStatus(widget.leadId, status);
        await _load();
        if (mounted) UiFeedback.success(context, 'Status updated');
      }
    } catch (e) {
      if (mounted) UiFeedback.parsedError(context, e);
    }
  }

  Future<void> _createQuotation() async {
    final lead = _lead ?? {};
    final clientName = ApiParse.field(lead, ['client_name'], fallback: 'Lead');
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationBuilderScreen(leadId: widget.leadId, clientName: clientName),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _approveQuotation(int quotationId) async {
    try {
      await ref.read(crmServiceProvider).approveQuotation(quotationId);
      await _load();
      if (mounted) UiFeedback.success(context, 'Quotation approved');
    } catch (e) {
      if (mounted) UiFeedback.parsedError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final lead = _lead ?? {};
    final name = ApiParse.field(lead, ['client_name'], fallback: 'Lead');
    final phone = ApiParse.field(lead, ['client_phone']);
    final email = ApiParse.field(lead, ['client_email']);
    final status = ApiParse.field(lead, ['status'], fallback: 'unknown');
    final source = ApiParse.field(lead, ['source']);

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card('Contact', [
              Text(phone),
              if (email.isNotEmpty) Text(email),
              Text('Source: $source'),
              Chip(label: Text(status.replaceAll('_', ' '))),
            ]),
            const SizedBox(height: 16),
            _card('Update Status', [
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('New'),
                    onPressed: () => _updateStatus('new'),
                  ),
                  ActionChip(
                    label: const Text('First Call'),
                    onPressed: () => _updateStatus('first_call'),
                  ),
                  ActionChip(
                    label: const Text('PDF Sent'),
                    onPressed: () => _updateStatus('pdf_sent'),
                  ),
                  ActionChip(
                    label: const Text('Sample Sent'),
                    onPressed: () => _updateStatus('sample_sent'),
                  ),
                  ActionChip(
                    label: const Text('Site Visit'),
                    onPressed: () => _updateStatus('site_visit'),
                  ),
                  ActionChip(
                    label: const Text('Negotiation'),
                    onPressed: () => _updateStatus('negotiation'),
                  ),
                  ActionChip(
                    label: const Text('Finalized'),
                    onPressed: () => _updateStatus('finalized'),
                  ),
                  ActionChip(
                    label: const Text('Lost'),
                    onPressed: () => _updateStatus('lost'),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 16),
            _card('Quotations (${_quotations.length})', [
              ElevatedButton.icon(
                onPressed: _createQuotation,
                icon: const Icon(Icons.add),
                label: const Text('Create Quotation'),
              ),
              const SizedBox(height: 12),
              if (_quotations.isEmpty)
                const Text('No quotations yet')
              else
                ..._quotations.map((q) {
                  final id = ApiParse.intField(q, ['id', 'ID']);
                  final qStatus =
                      ApiParse.field(q, ['status', 'Status'], fallback: '-');
                  return ListTile(
                    title: Text('Quotation #$id'),
                    subtitle: Text(qStatus),
                    trailing: id != null && qStatus != 'client_approved'
                        ? TextButton(
                            onPressed: () => _approveQuotation(id),
                            child: const Text('Approve'),
                          )
                        : null,
                  );
                }),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
