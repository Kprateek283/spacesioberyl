import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final workspaceProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.read(apiClientProvider);

  try {
    final actionItemsRes = await api.get('/workspace/action-items');
    final timelineRes = await api.get('/workspace/personal-timeline');

    return {
      'actionItems': actionItemsRes.data,
      'timeline': timelineRes.data,
    };
  } catch (e) {
    throw Exception('Failed to load workspace data: $e');
  }
});
