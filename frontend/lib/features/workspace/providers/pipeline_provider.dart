import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final pipelineProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.read(apiClientProvider);

  try {
    final response = await api.get('/projects/pipeline');
    return response.data as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Failed to load pipeline: $e');
  }
});
