// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../core/widgets/signature_canvas_widget.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/execution_service.dart';

class ClientSignoffScreen extends ConsumerStatefulWidget {
  final int? initialJobId;

  const ClientSignoffScreen({super.key, this.initialJobId});

  @override
  ConsumerState<ClientSignoffScreen> createState() =>
      _ClientSignoffScreenState();
}

class _ClientSignoffScreenState extends ConsumerState<ClientSignoffScreen> {
  final _jobIdController = TextEditingController();
  final _feedbackController = TextEditingController();
  String _status = 'client_approved';
  String? _signoffUrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialJobId != null) {
      _jobIdController.text = '${widget.initialJobId}';
    }
  }

  @override
  void dispose() {
    _jobIdController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final jobIdError =
        FormValidators.validateRequired(_jobIdController.text, 'Job ID');
    if (jobIdError != null) {
      UiFeedback.error(context, jobIdError);
      return;
    }
    if (_signoffUrl == null) {
      UiFeedback.error(context, 'Please capture client signature');
      return;
    }

    final jobId = int.tryParse(_jobIdController.text.trim());
    if (jobId == null) {
      UiFeedback.error(context, 'Invalid job ID');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(executionServiceProvider).recordClientSignoff(
            jobId: jobId,
            clientSignoffUrl: _signoffUrl!,
            status: _status,
            clientFeedback: _feedbackController.text.trim(),
          );
      if (mounted) {
        UiFeedback.success(context, 'Sign-off recorded');
      }
    } catch (e) {
      if (mounted) UiFeedback.parsedError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Sign-off'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DialogTextField(
            controller: _jobIdController,
            labelText: 'Job ID',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          const Text('Client Signature',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SignatureCanvasWidget(
            onSignatureComplete: (url) {
              setState(() => _signoffUrl = url);
              UiFeedback.success(context, 'Signature captured');
            },
          ),
          if (_signoffUrl != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Signature captured, will upload on submit.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          const SizedBox(height: 16),
          DialogDropdownField<String>(
            value: _status,
            items: const [
              DropdownMenuItem(
                  value: 'client_approved', child: Text('Client Approved')),
              DropdownMenuItem(
                  value: 'redo_required', child: Text('Redo Required')),
            ],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 16),
          DialogTextField(
            controller: _feedbackController,
            labelText: 'Client Feedback (optional)',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Sign-off'),
          ),
        ],
      ),
      ),
    );
  }
}
