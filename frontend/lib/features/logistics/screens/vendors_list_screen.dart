// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/cache_provider.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../../../core/widgets/ghost_mode_aware.dart';
import '../services/logistics_service.dart';

class VendorsListScreen extends ConsumerStatefulWidget {
  const VendorsListScreen({super.key});

  @override
  ConsumerState<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends ConsumerState<VendorsListScreen> {
  bool isCreatingVendor = false;

  Future<void> _showCreateVendorDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final contactPersonController = TextEditingController();
    String selectedPaymentMode = 'cash';

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Vendor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogTextField(
                controller: nameController,
                labelText: 'Company Name',
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: contactPersonController,
                labelText: 'Contact Person',
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
              GhostModeAware(
                child: DialogDropdownField<String>(
                  value: selectedPaymentMode,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'online', child: Text('Online')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      selectedPaymentMode = value;
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            isSubmitting: isCreatingVendor,
            submitText: 'Add',
            onSubmit: () async {
              // Validate required fields
              final nameError = FormValidators.validateRequired(
                nameController.text,
                'Company name',
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

              // Validate email if provided
              if (emailController.text.isNotEmpty) {
                final emailError = FormValidators.validateEmail(emailController.text);
                if (emailError != null) {
                  UiFeedback.error(context, emailError);
                  return;
                }
              }

              try {
                setState(() => isCreatingVendor = true);
                await ref.read(logisticsServiceProvider).createVendor(
                      companyName: nameController.text.trim(),
                      contactPerson: contactPersonController.text.trim(),
                      phone: phoneController.text.trim(),
                      email: emailController.text.isEmpty
                          ? null
                          : emailController.text.trim(),
                      defaultPaymentMode: selectedPaymentMode,
                    );

                Navigator.pop(ctx);
                // ignore: unused_result
                ref.refresh(cachedVendorsProvider);
                if (mounted) {
                  UiFeedback.success(context, 'Vendor added successfully');
                }
              } catch (e) {
                if (mounted) {
                  UiFeedback.parsedError(context, e);
                }
              } finally {
                setState(() => isCreatingVendor = false);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(cachedVendorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendors'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: vendorsAsync.when(
        data: (vendors) {
          return vendors.isEmpty
              ? const Center(child: Text('No vendors found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vendors.length,
                  itemBuilder: (ctx, index) {
                    final vendor = vendors[index];
                    return _buildVendorCard(vendor);
                  },
                );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0061a4)),
        ),
        error: (err, stack) => AsyncErrorView(
          error: err,
          onRetry: () => ref.invalidate(cachedVendorsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isCreatingVendor ? null : _showCreateVendorDialog,
        backgroundColor: const Color(0xFF0061a4),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVendorCard(Map<String, dynamic> vendor) {
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
                        vendor['company_name'] ?? 'Vendor',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendor['contact_person'] ?? 'No contact',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
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
                  vendor['phone'] ?? 'N/A',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (vendor['email'] != null)
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vendor['email'],
                      style: const TextStyle(fontSize: 13, color: Colors.blue),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Payment: ${(vendor['default_payment_mode'] as String?)?.replaceAll('_', ' ').toUpperCase() ?? 'N/A'}',
                style: const TextStyle(fontSize: 11, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
