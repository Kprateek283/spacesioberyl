// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../../../core/widgets/photo_preview_widget.dart';
import '../services/execution_service.dart';

// Riverpod provider for site updates by job
final siteUpdatesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
  (ref, jobId) async {
    return DatabaseHelper.instance.getCachedSiteUpdates(jobId);
  },
);

final selectedJobIdProvider = StateProvider<int?>((ref) => null);

final selectedJobUpdatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final jobId = ref.watch(selectedJobIdProvider);
  if (jobId == null) return <Map<String, dynamic>>[];
  return ref.watch(siteUpdatesProvider(jobId).future);
});

class SiteUpdatesScreen extends ConsumerStatefulWidget {
  final int? initialJobId;

  const SiteUpdatesScreen({super.key, this.initialJobId});

  @override
  ConsumerState<SiteUpdatesScreen> createState() => _SiteUpdatesScreenState();
}

class _SiteUpdatesScreenState extends ConsumerState<SiteUpdatesScreen> {
  bool isSubmitting = false;
  XFile? selectedPhoto;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.initialJobId != null) {
      Future.microtask(() async {
        ref.read(selectedJobIdProvider.notifier).state = widget.initialJobId;
        await _refreshJobUpdatesCache(widget.initialJobId!);
        if (mounted) ref.invalidate(selectedJobUpdatesProvider);
      });
    }
  }

  Future<void> _showCreateUpdateDialog() async {
    final descriptionController = TextEditingController();
    final siteIdController = TextEditingController();
    XFile? dialogPhoto = selectedPhoto;

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) => AlertDialog(
          title: const Text('Create Site Update'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DialogTextField(
                  controller: siteIdController,
                  labelText: 'Job ID',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DialogTextField(
                  controller: descriptionController,
                  labelText: 'Update Description',
                  hintText:
                      'e.g., Installation completed, Pending inspection, etc.',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                PhotoPreviewWidget(
                  photo: dialogPhoto,
                  label: 'Site Photo',
                  onCapture: () async {
                    final photo = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (photo != null) {
                      dialogSetState(() => dialogPhoto = photo);
                    }
                  },
                  onRemove: () => dialogSetState(() => dialogPhoto = null),
                ),
              ],
            ),
          ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            isSubmitting: isSubmitting,
            submitText: 'Create',
            onSubmit: () async {
              // Validate required fields
              final siteIdError = FormValidators.validateRequired(
                siteIdController.text,
                'Job ID',
              );
              if (siteIdError != null) {
                UiFeedback.error(context, siteIdError);
                return;
              }

              final descError = FormValidators.validateRequired(
                descriptionController.text,
                'Description',
              );
              if (descError != null) {
                UiFeedback.error(context, descError);
                return;
              }

              // Validate photo if provided
              if (dialogPhoto != null) {
                final photoError = FormValidators.validatePhotoFile(dialogPhoto);
                if (photoError != null) {
                  UiFeedback.error(context, photoError);
                  return;
                }
              }

              try {
                setState(() => isSubmitting = true);
                final jobId = int.tryParse(siteIdController.text.trim());
                if (jobId == null) {
                  UiFeedback.error(context, 'Job ID must be a valid number');
                  return;
                }

                await ref.read(executionServiceProvider).syncJobUpdate(
                      jobId: jobId,
                      notes: descriptionController.text.trim(),
                      updateTime: DateTime.now(),
                      photoUrl: dialogPhoto?.path,
                    );
                await _refreshJobUpdatesCache(jobId);
                Navigator.pop(ctx);
                selectedPhoto = null;
                ref.read(selectedJobIdProvider.notifier).state = jobId;
                // ignore: unused_result
                ref.refresh(selectedJobUpdatesProvider);
                if (mounted) {
                  UiFeedback.success(context, 'Site update created');
                }
              } catch (e) {
                if (mounted) {
                  UiFeedback.parsedError(context, e);
                }
              } finally {
                setState(() => isSubmitting = false);
              }
            },
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _refreshJobUpdatesCache(int jobId) async {
    try {
      final remote = await ref.read(executionServiceProvider).getJobUpdates(jobId);
      await DatabaseHelper.instance.cacheSiteUpdates(jobId, remote);
    } catch (_) {
      // Offline is expected; local cached updates remain visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(selectedJobUpdatesProvider);
    final selectedJobId = ref.watch(selectedJobIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Updates'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: updatesAsync.when(
        data: (updates) {
          if (selectedJobId == null) {
            return const Center(
              child: Text('Create an update first to load job updates'),
            );
          }
          return updates.isEmpty
              ? const Center(child: Text('No site updates yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: updates.length,
                  itemBuilder: (ctx, index) {
                    final update = updates[index];
                    return _buildUpdateCard(update);
                  },
                );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0061a4)),
        ),
        error: (err, stack) => AsyncErrorView(
          error: err,
          onRetry: () => ref.invalidate(selectedJobUpdatesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isSubmitting ? null : _showCreateUpdateDialog,
        backgroundColor: const Color(0xFF0061a4),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> update) {
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
                Text(
                  'Job ${update['installation_id'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDate(update['update_time']?.toString()),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              update['notes'] ?? 'No notes',
              style: const TextStyle(fontSize: 14),
            ),
            if (update['photo_url'] != null) ...[
              const SizedBox(height: 12),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.image, size: 40, color: Colors.grey),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, hh:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
