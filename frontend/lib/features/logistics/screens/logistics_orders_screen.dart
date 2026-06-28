import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_parse.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../../iam/services/iam_service.dart';
import '../services/logistics_service.dart';

import '../../../shared/widgets/dialog_action_buttons.dart';
import '../../../shared/widgets/dialog_fields.dart';

final logisticsOrdersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(logisticsServiceProvider).getOrders();
});

class LogisticsOrdersScreen extends ConsumerStatefulWidget {
  const LogisticsOrdersScreen({super.key});

  @override
  ConsumerState<LogisticsOrdersScreen> createState() => _LogisticsOrdersScreenState();
}

class _LogisticsOrdersScreenState extends ConsumerState<LogisticsOrdersScreen> {

  Future<void> _createPO(int orderId) async {
    final vendorCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Purchase Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogTextField(
              controller: vendorCtrl,
              labelText: 'Vendor ID',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DialogTextField(
              controller: amountCtrl,
              labelText: 'Total Amount',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DialogTextField(
              controller: dateCtrl,
              labelText: 'Expected Delivery (YYYY-MM-DD)',
            ),
          ],
        ),
        actions: [
          DialogActionButtons(
            onCancel: () => Navigator.pop(ctx),
            submitText: 'Create PO',
            onSubmit: () async {
              final vId = int.tryParse(vendorCtrl.text);
              final amt = double.tryParse(amountCtrl.text);
              if (vId == null || amt == null || dateCtrl.text.isEmpty) return;
              
              Navigator.pop(ctx);
              try {
                await ref.read(logisticsServiceProvider).createPurchaseOrder(
                      orderId: orderId,
                      vendorId: vId,
                      totalAmount: amt,
                      expectedDeliveryDate: dateCtrl.text.trim(),
                    );
                ref.invalidate(logisticsOrdersProvider);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PO Created')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _assignManager(int orderId) async {
    List<Map<String, dynamic>> users = [];
    try {
      users = await ref.read(iamServiceProvider).getUsers();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load users')));
      return;
    }
    
    final managers = users.where((u) {
       final r = (u['role'] ?? u['role_name'] ?? '').toString();
       return r.contains('manager') || r.contains('admin');
    }).toList();
    if (managers.isEmpty) managers.addAll(users);

    int? selectedManagerId;
    if (managers.isNotEmpty) selectedManagerId = int.tryParse(managers.first['id'].toString());

    if (selectedManagerId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid managers found')));
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Assign Manager'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Manager', style: TextStyle(fontSize: 12, color: Colors.grey)),
              DialogDropdownField<int>(
                value: selectedManagerId!,
                items: managers.map((u) {
                  return DropdownMenuItem<int>(
                    value: int.tryParse(u['id'].toString()),
                    child: Text('${u['name']} (${u['role'] ?? u['role_name']})'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedManagerId = v);
                  }
                },
              ),
            ],
          ),
          actions: [
            DialogActionButtons(
              onCancel: () => Navigator.pop(ctx),
              submitText: 'Assign',
              onSubmit: () async {
                if (selectedManagerId == null) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(logisticsServiceProvider).assignOrderManager(orderId, selectedManagerId!);
                  ref.invalidate(logisticsOrdersProvider);
                } catch (_) {}
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDispatch(int orderId) async {
    List<Map<String, dynamic>> users = [];
    try {
      users = await ref.read(iamServiceProvider).getUsers();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load users')));
      return;
    }
    
    final staffList = users.where((u) {
       final r = (u['role'] ?? u['role_name'] ?? '').toString();
       return r.contains('staff') || r.contains('admin') || r.contains('manager');
    }).toList();
    if (staffList.isEmpty) staffList.addAll(users);

    int? selectedStaffId;
    if (staffList.isNotEmpty) selectedStaffId = int.tryParse(staffList.first['id'].toString());

    if (selectedStaffId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid staff found')));
      return;
    }

    String responsibility = 'company_staff';
    final driverCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Schedule Dispatch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Staff', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DialogDropdownField<int>(
                  value: selectedStaffId!,
                  items: staffList.map((u) {
                    return DropdownMenuItem<int>(
                      value: int.tryParse(u['id'].toString()),
                      child: Text('${u['name']}'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedStaffId = v);
                    }
                  },
                ),
                const SizedBox(height: 12),
                const Text('Loading Responsibility', style: TextStyle(fontSize: 12, color: Colors.grey)),
                DialogDropdownField<String>(
                  value: responsibility,
                  items: const [
                    DropdownMenuItem(value: 'company_staff', child: Text('Company Staff')),
                    DropdownMenuItem(value: 'contractor', child: Text('Contractor')),
                  ],
                  onChanged: (v) => setDialogState(() => responsibility = v ?? responsibility),
                ),
                const SizedBox(height: 12),
                DialogTextField(controller: driverCtrl, labelText: 'Driver Name (Optional)'),
                const SizedBox(height: 12),
                DialogTextField(controller: vehicleCtrl, labelText: 'Vehicle No (Optional)'),
              ],
            ),
          ),
          actions: [
            DialogActionButtons(
              onCancel: () => Navigator.pop(ctx),
              submitText: 'Schedule',
              onSubmit: () async {
                if (selectedStaffId == null) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(logisticsServiceProvider).createDispatch(
                        orderId: orderId,
                        operationsStaffId: selectedStaffId!,
                        loadingResponsibility: responsibility,
                        transportDriverName: driverCtrl.text.trim(),
                        transportVehicleNo: vehicleCtrl.text.trim(),
                      );
                  ref.invalidate(logisticsOrdersProvider);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispatch Scheduled')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final ordersAsync = ref.watch(logisticsOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistics Orders'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
      ),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No active orders.\nApprove a CRM quotation first.',
                textAlign: TextAlign.center,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(logisticsOrdersProvider),
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i];
                final id = ApiParse.intField(o, ['id', 'ID']);
                final status =
                    ApiParse.field(o, ['status', 'Status'], fallback: '-');
                final client =
                    ApiParse.field(o, ['client_name', 'ClientName'],
                        fallback: 'Order');
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExpansionTile(
                    leading: const Icon(Icons.inventory_2),
                    title: Text('$client (#$id)'),
                    subtitle: Text(status.replaceAll('_', ' ')),
                    children: [
                      ButtonBar(
                        alignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: id != null ? () => _assignManager(id) : null,
                            child: const Text('Assign Manager'),
                          ),
                          TextButton(
                            onPressed: id != null ? () => _createPO(id) : null,
                            child: const Text('Create PO'),
                          ),
                          TextButton(
                            onPressed: id != null ? () => _createDispatch(id) : null,
                            child: const Text('Schedule Dispatch'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          error: e,
          onRetry: () => ref.invalidate(logisticsOrdersProvider),
        ),
      ),
    );
  }
}
