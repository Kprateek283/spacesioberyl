import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/api_parse.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../services/hr_service.dart';

final adminExpensesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(hrServiceProvider).getExpenses();
});

class AdminExpensesScreen extends ConsumerWidget {
  const AdminExpensesScreen({super.key});

  String _fmt(String? d) {
    if (d == null || d.isEmpty) return '-';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(adminExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Ledger'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
      ),
      body: expensesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No expenses recorded'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminExpensesProvider),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = items[i];
                final amount = (e['amount'] as num?)?.toDouble() ?? 0;
                final person = ApiParse.field(e, ['person_paid']);
                final ctx = ApiParse.field(e, ['context']);
                final date = ApiParse.field(e, ['expense_date']);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0061a4),
                    child: Text('₹', style: TextStyle(color: Colors.white)),
                  ),
                  title: Text('₹${amount.toStringAsFixed(0)} — $ctx'),
                  subtitle: Text('Paid by: $person · ${_fmt(date)}'),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          error: e,
          onRetry: () => ref.invalidate(adminExpensesProvider),
        ),
      ),
    );
  }
}
