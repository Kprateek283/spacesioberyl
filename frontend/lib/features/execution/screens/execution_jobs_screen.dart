import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/api_parse.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../services/execution_service.dart';
import 'job_detail_screen.dart';

final executionJobsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, bool>((ref, myOnly) async {
  return ref.watch(executionServiceProvider).getJobs(myTasksOnly: myOnly);
});

class ExecutionJobsScreen extends ConsumerWidget {
  final bool myTasksOnly;

  const ExecutionJobsScreen({super.key, this.myTasksOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(executionJobsProvider(myTasksOnly));

    return Scaffold(
      appBar: AppBar(
        title: Text(myTasksOnly ? 'My Jobs' : 'All Jobs'),
        backgroundColor: const Color(0xFF0061a4),
        foregroundColor: Colors.white,
      ),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(
              child: Text(
                'No installation jobs yet',
                textAlign: TextAlign.center,
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(executionJobsProvider(myTasksOnly)),
            child: ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (_, i) {
                final j = jobs[i];
                final id = ApiParse.intField(j, ['id', 'ID']);
                final status =
                    ApiParse.field(j, ['status', 'Status'], fallback: '-');
                final orderId =
                    ApiParse.field(j, ['order_id', 'OrderID'], fallback: '-');

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.construction),
                    title: Text('Job #$id'),
                    subtitle: Text('Order $orderId · ${status.replaceAll('_', ' ')}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: id == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(jobId: id),
                              ),
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
          onRetry: () => ref.invalidate(executionJobsProvider(myTasksOnly)),
        ),
      ),
    );
  }
}
