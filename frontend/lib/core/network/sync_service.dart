import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'mock_upload_service.dart';
import '../local_db/database_helper.dart';

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  final pending = await DatabaseHelper.instance.getPendingMutations();
  return pending.length;
});

/// Mutations that failed 5 sync attempts and were dropped, so the UI can
/// surface them instead of silently discarding the user's data.
final droppedMutationsProvider = StateProvider<List<String>>((ref) => []);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    ref.watch(apiClientProvider),
    onQueueChanged: () => ref.invalidate(pendingSyncCountProvider),
    onMutationDropped: (endpoint) => ref
        .read(droppedMutationsProvider.notifier)
        .update((state) => [...state, endpoint]),
  );
  ref.onDispose(service.dispose);
  return service;
});

class SyncService {
  final ApiClient _apiClient;
  final VoidCallback? onQueueChanged;
  final ValueChanged<String>? onMutationDropped;
  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  SyncService(this._apiClient, {this.onQueueChanged, this.onMutationDropped}) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        _syncOutboxQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> triggerManualSync() async {
    await _syncOutboxQueue();
  }

  Future<void> _syncOutboxQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final dbHelper = DatabaseHelper.instance;
      final pendingMutations = await dbHelper.getPendingMutations();

      if (pendingMutations.isEmpty) return;

      for (var mutation in pendingMutations) {
        final id = mutation['id'] as int;
        final endpoint = mutation['endpoint'] as String;
        final method = mutation['method'] as String;
        final payloadString = mutation['payload'] as String;
        final hasFile = mutation['has_file'] == 1;
        final localFilePath = mutation['local_file_path'] as String?;
        final fileFieldKey = mutation['file_field_key'] as String?;
        final retryCount = mutation['retry_count'] as int;

        if (retryCount >= 5) {
          await dbHelper.removeMutation(id);
          onMutationDropped?.call(endpoint);
          continue;
        }

        try {
          final payload = jsonDecode(payloadString) as Map<String, dynamic>;

          // TODO: replace with a real upload once a generic backend upload
          // endpoint exists (see issue/01-backend-issues.md).
          if (hasFile && localFilePath != null && fileFieldKey != null) {
            _setNestedField(payload, fileFieldKey, MockUploadService.toMockUrl(localFilePath));
          }

          if (method.toUpperCase() == 'POST') {
            await _apiClient.post(endpoint, data: payload);
          } else if (method.toUpperCase() == 'PATCH') {
            await _apiClient.patch(endpoint, data: payload);
          }

          await dbHelper.removeMutation(id);
        } catch (_) {
          await dbHelper.incrementRetryCount(id);
          break;
        }
      }
    } finally {
      _isSyncing = false;
      onQueueChanged?.call();
    }
  }

  /// Sets [value] at a dotted path inside [payload], where numeric segments
  /// index into lists, e.g. 'updates.0.photo_url' -> payload['updates'][0]['photo_url'].
  void _setNestedField(Map<String, dynamic> payload, String dottedKey, String value) {
    final segments = dottedKey.split('.');
    dynamic current = payload;
    for (var i = 0; i < segments.length - 1; i++) {
      final segment = segments[i];
      final index = int.tryParse(segment);
      if (index != null && current is List) {
        current = current[index];
      } else if (current is Map) {
        current = current[segment];
      } else {
        return; // Path doesn't resolve; nothing to set.
      }
    }

    final lastSegment = segments.last;
    final lastIndex = int.tryParse(lastSegment);
    if (lastIndex != null && current is List) {
      current[lastIndex] = value;
    } else if (current is Map) {
      current[lastSegment] = value;
    }
  }
}
