// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';
import '../../../core/widgets/ghost_mode_aware.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/hr_service.dart';

// Riverpod provider for HR expenses
final myExpensesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final cached = await DatabaseHelper.instance.getCachedExpenses();
  return cached
      .map(
        (item) => <String, dynamic>{
          'id': item['id']?.toString() ?? '',
          'description': (item['context'] ?? '').toString(),
          'amount': (item['amount'] as num?)?.toDouble() ?? 0.0,
          'category': (item['person_paid'] ?? 'unknown').toString(),
          'status': 'submitted',
          'created_at': (item['expense_date'] ?? '').toString(),
        },
      )
      .toList();
});

class MyExpensesScreen extends ConsumerStatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  ConsumerState<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends ConsumerState<MyExpensesScreen> {
  bool isCreatingExpense = false;
  String filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _refreshExpensesCache();
      if (mounted) {
        // ignore: unused_result
        ref.refresh(myExpensesProvider);
      }
    });
  }

  Future<void> _showCreateExpenseDialog() async {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final personPaidController = TextEditingController();
    XFile? receiptPhoto;
    final picker = ImagePicker();

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
        title: const Text('Create Expense'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogTextField(
                controller: descriptionController,
                labelText: 'Description',
                hintText: 'e.g., Office lunch, Travel, etc.',
              ),
              const SizedBox(height: 12),
              GhostModeAware(
                child: DialogTextField(
                  controller: amountController,
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(height: 12),
              DialogTextField(
                controller: personPaidController,
                labelText: 'Person Paid',
                hintText: 'Name of person who made payment',
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final photo = await picker.pickImage(source: ImageSource.gallery);
                  if (photo != null) setModal(() => receiptPhoto = photo);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: receiptPhoto == null
                        ? const Icon(Icons.image, size: 32, color: Colors.grey)
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                receiptPhoto == null ? 'Tap to upload receipt' : 'Receipt selected',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            isSubmitting: isCreatingExpense,
            submitText: 'Create',
            onSubmit: () async {
              // Validate all fields
              final descError = FormValidators.validateRequired(
                descriptionController.text,
                'Description',
              );
              if (descError != null) {
                UiFeedback.error(context, descError);
                return;
              }

              final amountError = FormValidators.validateAmount(
                amountController.text,
                fieldName: 'Amount',
              );
              if (amountError != null) {
                UiFeedback.error(context, amountError);
                return;
              }

              final personPaidError = FormValidators.validateRequired(
                personPaidController.text,
                'Person Paid',
              );
              if (personPaidError != null) {
                UiFeedback.error(context, personPaidError);
                return;
              }

              try {
                setState(() => isCreatingExpense = true);
                await ref.read(hrServiceProvider).createExpense(
                      amount: double.parse(amountController.text),
                      personPaid: personPaidController.text.trim(),
                      context: descriptionController.text.trim(),
                      expenseDate:
                          DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      receiptImagePath: receiptPhoto?.path,
                    );
                await _refreshExpensesCache();
                Navigator.pop(ctx);
                // ignore: unused_result
                ref.refresh(myExpensesProvider);
                if (mounted) {
                  UiFeedback.success(context, 'Expense created successfully');
                }
              } catch (e) {
                if (mounted) {
                  UiFeedback.parsedError(context, e);
                }
              } finally {
                setState(() => isCreatingExpense = false);
              }
            },
          ),
        ],
      ),
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(myExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses'),
      ),
      body: expensesAsync.when(
        data: (expenses) {
          // Filter expenses based on status
          final filteredExpenses = filterStatus == 'all'
              ? expenses
              : expenses.where((exp) => exp['status'] == filterStatus).toList();

          // Calculate totals
          double totalAmount = 0;
          double submittedAmount = 0;
          for (var exp in expenses) {
            final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
            totalAmount += amount;
            if (exp['status'] == 'submitted' || exp['status'] == 'approved') {
              submittedAmount += amount;
            }
          }

          return Column(
            children: [
              // Summary Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Submitted',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${submittedAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Draft', 'draft'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Submitted', 'submitted'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', 'approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected', 'rejected'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expenses List
              Expanded(
                child: filteredExpenses.isEmpty
                    ? const Center(child: Text('No expenses found'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredExpenses.length,
                        itemBuilder: (ctx, index) {
                          final expense = filteredExpenses[index];
                          return _buildExpenseCard(expense);
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
          onRetry: () => ref.invalidate(myExpensesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isCreatingExpense ? null : _showCreateExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => filterStatus = status);
      },
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onPrimaryContainer : AppColors.onSurface,
      ),
    );
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final status = expense['status'] as String? ?? 'draft';
    final description = expense['description'] as String?;
    final amount = expense['amount'] as num?;
    final category = expense['category'] as String?;
    final createdAt = expense['created_at'] as String?;
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
                        description ?? 'Expense',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category?.replaceAll('_', ' ').toUpperCase() ?? 'N/A'} • ${_formatDate(createdAt)}',
                        style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${amount?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return AppColors.onSurfaceVariant;
      case 'submitted':
        return AppColors.secondary;
      case 'approved':
        return AppColors.primary;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _refreshExpensesCache() async {
    final role = ref.read(authProvider).userRole;
    if (role != 'admin' && role != 'super_admin') return;

    try {
      final data = await ref.read(hrServiceProvider).getExpenses();
      await DatabaseHelper.instance.cacheExpenses(data);
    } catch (_) {}
  }
}
