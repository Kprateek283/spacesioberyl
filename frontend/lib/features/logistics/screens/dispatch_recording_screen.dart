// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../services/logistics_service.dart';

class DispatchRecordingScreen extends ConsumerStatefulWidget {
  const DispatchRecordingScreen({super.key});

  @override
  ConsumerState<DispatchRecordingScreen> createState() => _DispatchRecordingScreenState();
}

class _DispatchRecordingScreenState extends ConsumerState<DispatchRecordingScreen> {
  bool isSubmitting = false;
  final _dispatchIdController = TextEditingController();
  final _notesController = TextEditingController();
  final _challanUrlController = TextEditingController();

  @override
  void dispose() {
    _dispatchIdController.dispose();
    _notesController.dispose();
    _challanUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitDispatchRecord(String type) async {
    final dispatchId = int.tryParse(_dispatchIdController.text.trim());
    if (dispatchId == null) {
      UiFeedback.error(context, 'Enter a valid Dispatch ID');
      return;
    }

    try {
      setState(() => isSubmitting = true);
      await ref.read(logisticsServiceProvider).logDispatchEvent(
            dispatchId: dispatchId,
            type: type,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            challanUrl: _challanUrlController.text.trim().isEmpty
                ? null
                : _challanUrlController.text.trim(),
          );

      if (mounted) {
        UiFeedback.success(context, 'Dispatch event logged successfully');
        _notesController.clear();
      }
    } catch (e) {
      if (mounted) {
        UiFeedback.parsedError(context, e);
      }
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Dispatch'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dispatch Event Log',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Log dispatch or delivery updates for an existing dispatch.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              DialogTextField(
                controller: _dispatchIdController,
                labelText: 'Dispatch ID',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: _notesController,
                labelText: 'Notes (Optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: _challanUrlController,
                labelText: 'Challan URL (Optional)',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),

              // Event Type Buttons
              _buildEventTypeButton(
                'Dispatch Logged',
                'Use when items are dispatched',
                'dispatch',
              ),
              const SizedBox(height: 10),
              _buildEventTypeButton(
                'Delivery Logged',
                'Use when items are delivered',
                'delivery',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTypeButton(String title, String subtitle, String eventType) {
    return ElevatedButton(
      onPressed: isSubmitting ? null : () => _submitDispatchRecord(eventType),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
