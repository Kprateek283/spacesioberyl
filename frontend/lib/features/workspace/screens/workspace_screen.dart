import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workspace_provider.dart';
import '../../../core/theme/app_colors.dart';

class WorkspaceScreen extends ConsumerWidget {
  final bool isAdmin;
  const WorkspaceScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceData = ref.watch(workspaceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Command Center', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: workspaceData.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
        data: (data) {
          final actionItems = data['actionItems'] as List? ?? [];
          final timeline = data['timeline'] as List? ?? [];

          return RefreshIndicator(
            onRefresh: () => ref.refresh(workspaceProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildQuickActions(context),
                if (isAdmin) ...[
                  const SizedBox(height: 32),
                  const Text('Manager Inbox', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildActionItems(actionItems),
                ],
                const SizedBox(height: 32),
                const Text('My Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTimeline(timeline),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ActionCard(icon: Icons.access_time, label: 'Clock In/Out', onTap: () {})),
        const SizedBox(width: 8),
        Expanded(child: _ActionCard(icon: Icons.event_note, label: 'Request Leave', onTap: () {})),
        const SizedBox(width: 8),
        Expanded(child: _ActionCard(icon: Icons.receipt, label: 'Claim Expense', onTap: () {})),
      ],
    );
  }

  Widget _buildActionItems(List actionItems) {
    if (actionItems.isEmpty) {
      return const Text('No pending actions', style: TextStyle(color: AppColors.textTertiary));
    }
    return Column(
      children: actionItems.map((item) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              item['urgency'] == 'HIGH' ? Icons.warning : Icons.info,
              color: item['urgency'] == 'HIGH' ? AppColors.error : AppColors.primary,
            ),
            title: Text(item['title'] ?? ''),
            subtitle: Text(item['subtitle'] ?? ''),
            trailing: ElevatedButton(
              onPressed: () {},
              child: const Text('Review'),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeline(List timeline) {
    if (timeline.isEmpty) {
      return const Text('No recent activity', style: TextStyle(color: AppColors.textTertiary));
    }
    return Column(
      children: timeline.map((event) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.circle, size: 12, color: AppColors.primary),
          title: Text(event['title'] ?? ''),
          subtitle: Text(event['status'] ?? ''),
          trailing: Text(
            event['timestamp'] != null ? event['timestamp'].toString().substring(0, 10) : '',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
