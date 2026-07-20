// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/cache_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../../../core/widgets/ghost_mode_aware.dart';
import '../services/execution_service.dart';

class InstallersListScreen extends ConsumerStatefulWidget {
  const InstallersListScreen({super.key});

  @override
  ConsumerState<InstallersListScreen> createState() => _InstallersListScreenState();
}

class _InstallersListScreenState extends ConsumerState<InstallersListScreen> {
  bool isCreatingInstaller = false;
  String filterExpertise = 'all';

  Future<void> _showCreateInstallerDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final rateController = TextEditingController();
    String selectedExpertise = 'electrical';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Installer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogTextField(
                controller: nameController,
                labelText: 'Installer Name',
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: phoneController,
                labelText: 'Phone Number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DialogDropdownField<String>(
                value: selectedExpertise,
                items: const [
                  DropdownMenuItem(value: 'electrical', child: Text('Electrical')),
                  DropdownMenuItem(value: 'plumbing', child: Text('Plumbing')),
                  DropdownMenuItem(value: 'hvac', child: Text('HVAC')),
                  DropdownMenuItem(value: 'solar', child: Text('Solar')),
                  DropdownMenuItem(value: 'carpentry', child: Text('Carpentry')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedExpertise = value;
                  }
                },
              ),
              const SizedBox(height: 12),
              GhostModeAware(
                child: DialogTextField(
                  controller: rateController,
                  labelText: 'Standard Rate (₹/hour)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            isSubmitting: isCreatingInstaller,
            submitText: 'Add',
            onSubmit: () async {
              // Validate all fields
              final nameError = FormValidators.validateRequired(
                nameController.text,
                'Installer name',
              );
              if (nameError != null) {
                UiFeedback.error(context, nameError);
                return;
              }

              final phoneError = FormValidators.validatePhone(phoneController.text);
              if (phoneError != null) {
                UiFeedback.error(context, phoneError);
                return;
              }

              final rateError = FormValidators.validateRate(
                rateController.text,
                fieldName: 'Standard rate',
              );
              if (rateError != null) {
                UiFeedback.error(context, rateError);
                return;
              }

              try {
                setState(() => isCreatingInstaller = true);
                await ref.read(executionServiceProvider).createInstaller(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      expertiseArea: selectedExpertise,
                      standardRate: double.parse(rateController.text),
                    );

                Navigator.pop(ctx);
                // ignore: unused_result
                ref.refresh(cachedInstallersProvider);
                if (mounted) {
                  UiFeedback.success(context, 'Installer added successfully');
                }
              } catch (e) {
                if (mounted) {
                  UiFeedback.parsedError(context, e);
                }
              } finally {
                setState(() => isCreatingInstaller = false);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final installersAsync = ref.watch(cachedInstallersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Installers'),

        elevation: 0,
      ),
      body: installersAsync.when(
        data: (installers) {
          // Filter by expertise
          final filteredInstallers = filterExpertise == 'all'
              ? installers
              : installers.where((inst) => inst['expertise_area'] == filterExpertise).toList();

          return Column(
            children: [
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Electrical', 'electrical'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Plumbing', 'plumbing'),
                      const SizedBox(width: 8),
                      _buildFilterChip('HVAC', 'hvac'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Solar', 'solar'),
                    ],
                  ),
                ),
              ),

              // Installers List
              Expanded(
                child: filteredInstallers.isEmpty
                    ? const Center(child: Text('No installers found'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredInstallers.length,
                        itemBuilder: (ctx, index) {
                          final installer = filteredInstallers[index];
                          return _buildInstallerCard(installer);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (err, stack) => AsyncErrorView(
          error: err,
          onRetry: () => ref.invalidate(cachedInstallersProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isCreatingInstaller ? null : _showCreateInstallerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String expertise) {
    final isSelected = filterExpertise == expertise;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => filterExpertise = expertise);
      },
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurface,
      ),
    );
  }

  Widget _buildInstallerCard(Map<String, dynamic> installer) {
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        installer['name'] ?? 'Installer',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (installer['expertise_area'] as String?)?.replaceAll('_', ' ').toUpperCase() ?? 'N/A',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹${(installer['standard_rate'] as num?)?.toStringAsFixed(0) ?? '0'}/hr',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  installer['phone'] ?? 'N/A',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
