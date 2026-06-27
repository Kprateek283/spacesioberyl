import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/sync_service.dart';

/// Shows offline queue status at the top of the app shell.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingSyncCountProvider);
    final syncService = ref.watch(syncServiceProvider);

    return pendingAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();
        return MaterialBanner(
          content: Text('Syncing $count offline item${count == 1 ? '' : 's'}...'),
          leading: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          actions: [
            TextButton(
              onPressed: () => syncService.triggerManualSync(),
              child: const Text('Retry'),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
