import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/pipeline_provider.dart';
import '../../../core/theme/app_colors.dart';

class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipelineData = ref.watch(pipelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified Pipeline', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: pipelineData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
        data: (projects) {
          final leads = projects.where((p) => p['stage'] == 'LEAD').toList();
          final procurement = projects.where((p) => p['stage'] == 'PROCUREMENT').toList();
          final execution = projects.where((p) => p['stage'] == 'EXECUTION').toList();

          return PageView(
            children: [
              _PipelineColumn(title: 'Active Leads', projects: leads),
              _PipelineColumn(title: 'Awaiting Procurement', projects: procurement),
              _PipelineColumn(title: 'Active Installations', projects: execution),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open new lead dialog/screen
          // For now, this is a placeholder
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.onPrimary),
      ),
    );
  }
}

class _PipelineColumn extends StatelessWidget {
  final String title;
  final List projects;

  const _PipelineColumn({required this.title, required this.projects});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${projects.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final p = projects[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      context.go('/pipeline/project/${p['lead_id']}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['client_name'] ?? 'Unknown Client',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.label_outline, size: 16, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                (p['status'] ?? '').toString().toUpperCase(),
                                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
