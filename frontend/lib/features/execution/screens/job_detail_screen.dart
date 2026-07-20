import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../../../core/widgets/ghost_mode_aware.dart';
import '../services/execution_service.dart';
import 'site_updates_screen.dart';
import 'client_signoff_screen.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final int jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  List<Map<String, dynamic>> _updates = [];
  Map<String, dynamic> _ledger = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final svc = ref.read(executionServiceProvider);
      final updates = await svc.getJobUpdates(widget.jobId);
      Map<String, dynamic> ledger = {};
      try {
        ledger = await svc.getContractorLedger(widget.jobId);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _updates = updates;
          _ledger = ledger;
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

  Future<void> _assignInstaller() async {
    final installerCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Installer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogTextField(
              controller: installerCtrl,
              labelText: 'Installer ID',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DialogTextField(
              controller: priceCtrl,
              labelText: 'Agreed Price',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DialogTextField(
              controller: dateCtrl,
              labelText: 'Est. Completion (YYYY-MM-DD)',
            ),
          ],
        ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            submitText: 'Assign',
            onSubmit: () async {
              final installerId = int.tryParse(installerCtrl.text);
              final price = double.tryParse(priceCtrl.text);
              if (installerId == null || price == null || dateCtrl.text.isEmpty) {
                UiFeedback.error(context, 'Invalid input');
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(executionServiceProvider).assignInstallerToJob(
                      jobId: widget.jobId,
                      installerId: installerId,
                      agreedInstallerPrice: price,
                      estimatedCompletionDate: dateCtrl.text.trim(),
                    );
                if (mounted) {
                  UiFeedback.success(context, 'Installer assigned');
                  await _load();
                }
              } catch (e) {
                if (mounted) UiFeedback.parsedError(context, e);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _contractorAction(String action) async {
    try {
      final svc = ref.read(executionServiceProvider);
      if (action == 'check-in') {
        await svc.contractorCheckIn(widget.jobId, verificationNotes: 'Manual Check-in via App');
        if (mounted) UiFeedback.success(context, 'Checked in');
      } else if (action == 'check-out') {
        await svc.contractorCheckOut(widget.jobId);
        if (mounted) UiFeedback.success(context, 'Checked out');
      } else if (action == 'payment') {
        final amtCtrl = TextEditingController();
        final refCtrl = TextEditingController();
        String pType = 'advance';
        String pMode = 'upi';
        
        await showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: const Text('Record Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pMode == 'cash')
                    GhostModeAware(
                      child: DialogTextField(controller: amtCtrl, labelText: 'Amount (Cash)', keyboardType: TextInputType.number),
                    )
                  else
                    DialogTextField(controller: amtCtrl, labelText: 'Amount', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  DialogTextField(controller: refCtrl, labelText: 'Transaction Ref (Optional)'),
                  const SizedBox(height: 12),
                  DialogDropdownField<String>(
                    value: pType,
                    items: const [
                      DropdownMenuItem(value: 'advance', child: Text('Advance')),
                      DropdownMenuItem(value: 'final_discharge', child: Text('Final Discharge')),
                    ],
                    onChanged: (v) => setDialogState(() => pType = v ?? pType),
                  ),
                  const SizedBox(height: 12),
                  DialogDropdownField<String>(
                    value: pMode,
                    items: const [
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    ],
                    onChanged: (v) => setDialogState(() => pMode = v ?? pMode),
                  ),
                ],
              ),
              actions: [
                DialogActionButtons(
                  onCancel: () => Navigator.pop(ctx),
                  submitText: 'Record',
                  onSubmit: () async {
                    final amt = double.tryParse(amtCtrl.text);
                    if (amt == null) {
                      UiFeedback.error(context, 'Enter a valid amount');
                      return;
                    }
                    Navigator.pop(ctx);
                    // Navigator.pop resolves the outer `await showDialog(...)`
                    // immediately, so this call must handle its own
                    // success/failure feedback rather than relying on the
                    // caller's try/catch below.
                    try {
                      await svc.recordContractorPayment(
                        jobId: widget.jobId,
                        amount: amt,
                        paymentType: pType,
                        paymentMode: pMode,
                        transactionReference: refCtrl.text,
                      );
                      if (mounted) {
                        UiFeedback.success(context, 'Payment recorded');
                        await _load();
                      }
                    } catch (e) {
                      if (mounted) UiFeedback.parsedError(context, e);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      }
      await _load();
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Job #${widget.jobId}'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.photo_camera, size: 18),
                  label: const Text('Site Updates'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SiteUpdatesScreen(initialJobId: widget.jobId),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.draw, size: 18),
                  label: const Text('Sign-off'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ClientSignoffScreen(initialJobId: widget.jobId),
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.person_add, size: 18),
                  label: const Text('Assign Installer'),
                  onPressed: _assignInstaller,
                ),
                ActionChip(
                  avatar: const Icon(Icons.login, size: 18),
                  label: const Text('Check In'),
                  onPressed: () => _contractorAction('check-in'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.logout, size: 18),
                  label: const Text('Check Out'),
                  onPressed: () => _contractorAction('check-out'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.payment, size: 18),
                  label: const Text('Record Payment'),
                  onPressed: () => _contractorAction('payment'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Site Updates (${_updates.length})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ..._updates.map((u) {
              final notes = ApiParse.field(u, ['notes', 'Notes']);
              final time = ApiParse.field(u, ['update_time', 'UpdateTime']);
              return ListTile(
                dense: true,
                title: Text(notes),
                subtitle: Text(time),
              );
            }),
            if (_ledger.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Contractor Ledger',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_ledger.toString()),
            ],
          ],
        ),
      ),
    );
  }
}
