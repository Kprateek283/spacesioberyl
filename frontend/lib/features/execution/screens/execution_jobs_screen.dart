import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/api_parse.dart';
import '../../../shared/widgets/async_error_view.dart';
import '../services/execution_service.dart';
import 'job_detail_screen.dart';

final executionJobsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, bool>((ref, myOnly) async {
  return ref.watch(executionServiceProvider).getJobs(myTasksOnly: myOnly);
});

/// Job status lifecycle as actually tracked by `installations.status`.
const _stages = ['assigned', 'in_progress', 'client_approved'];

class ExecutionJobsScreen extends ConsumerWidget {
  final bool myTasksOnly;

  const ExecutionJobsScreen({super.key, this.myTasksOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(executionJobsProvider(myTasksOnly));

    return Scaffold(
      appBar: AppBar(
        title: Text(myTasksOnly ? 'My Jobs' : 'All Jobs'),
      ),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(
              child: Text('No installation jobs yet', textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(executionJobsProvider(myTasksOnly)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (_, i) => _JobCard(job: jobs[i]),
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

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final id = ApiParse.intField(job, ['id', 'ID']);
    final status = ApiParse.field(job, ['status', 'Status'], fallback: 'assigned');
    final orderId = ApiParse.field(job, ['order_id', 'OrderID'], fallback: '-');
    final estCompletion = ApiParse.field(job, ['estimated_completion_date', 'EstimatedCompletionDate']);

    final isRedo = status == 'redo_required';
    final stageIndex = isRedo ? 1 : _stages.indexOf(status).clamp(0, _stages.length - 1);
    final accent = isRedo
        ? AppColors.error
        : (status == 'client_approved' ? AppColors.primary : AppColors.warning);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: id == null
            ? null
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: id)),
                ),
        child: Stack(
          children: [
            Positioned(left: 0, top: 0, bottom: 0, width: 6, child: Container(color: accent)),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORDER #$orderId',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('Job #$id', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      _StatusPill(status: status, accent: accent),
                    ],
                  ),
                  if (estCompletion.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.event, size: 18, color: AppColors.outline),
                        const SizedBox(width: 6),
                        Text('Est. Completion: $estCompletion', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Assigned', style: _stageLabelStyle(0, stageIndex)),
                      Text('In Progress', style: _stageLabelStyle(1, stageIndex)),
                      Text('Approved', style: _stageLabelStyle(2, stageIndex)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: List.generate(_stages.length, (i) {
                          final filled = i <= stageIndex;
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: i == _stages.length - 1 ? 0 : 2),
                              color: filled ? accent : AppColors.surfaceVariant,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _stageLabelStyle(int index, int currentStage) {
    final active = index <= currentStage;
    return TextStyle(
      fontSize: 11,
      fontWeight: active ? FontWeight.bold : FontWeight.normal,
      color: active ? AppColors.primary : AppColors.outline,
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final Color accent;

  const _StatusPill({required this.status, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent),
      ),
    );
  }
}
