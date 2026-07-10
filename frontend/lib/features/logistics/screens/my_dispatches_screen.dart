import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/ui_feedback.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../services/logistics_service.dart';

final myDispatchesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(logisticsServiceProvider).getMyDispatches();
});

class MyDispatchesScreen extends ConsumerWidget {
  const MyDispatchesScreen({super.key});

  Future<void> _logEvent(
    WidgetRef ref,
    BuildContext context,
    int dispatchId,
    String type,
  ) async {
    try {
      await ref.read(logisticsServiceProvider).logDispatchEvent(
            dispatchId: dispatchId,
            type: type,
            notes: type == 'dispatch' ? 'Left warehouse' : 'Delivered to site',
          );
      ref.invalidate(myDispatchesProvider);
      if (context.mounted) {
        UiFeedback.success(context, '${type == 'dispatch' ? 'Dispatch' : 'Delivery'} logged');
      }
    } catch (e) {
      if (context.mounted) UiFeedback.parsedError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatchesAsync = ref.watch(myDispatchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dispatches'),
      ),
      body: dispatchesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No dispatch tasks assigned'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myDispatchesProvider),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final d = items[i];
                final id = ApiParse.intField(d, ['id', 'ID']);
                final orderId =
                    ApiParse.field(d, ['order_id', 'OrderID'], fallback: '-');
                final driver = ApiParse.field(
                    d, ['transport_driver_name', 'TransportDriverName']);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dispatch #$id · Order $orderId',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (driver.isNotEmpty) Text('Driver: $driver'),
                        const SizedBox(height: 12),
                        if (id != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _logEvent(ref, context, id, 'dispatch'),
                                child: const Text('Log Dispatch'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () =>
                                    _logEvent(ref, context, id, 'delivery'),
                                child: const Text('Log Delivery'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AsyncErrorView(
          error: e,
          onRetry: () => ref.invalidate(myDispatchesProvider),
        ),
      ),
    );
  }
}
