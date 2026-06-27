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

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(apiClientProvider),
    onQueueChanged: () => ref.invalidate(pendingSyncCountProvider),
  );
});

class SyncService {
  final ApiClient _apiClient;
  final VoidCallback? onQueueChanged;
  bool _isSyncing = false;

  SyncService(this._apiClient, {this.onQueueChanged}) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        _syncOutboxQueue();
      }
    });
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

        if (retryCount >= 5) continue;

        try {
          final payload = jsonDecode(payloadString) as Map<String, dynamic>;

          if (hasFile && localFilePath != null && fileFieldKey != null) {
            payload[fileFieldKey] = payload[fileFieldKey] ??
                MockUploadService.toMockUrl(localFilePath);
          }

          payload.forEach((key, value) {
            if (key.toString().endsWith('_url') &&
                value is String &&
                !MockUploadService.isHttpUrl(value) &&
                value.isNotEmpty) {
              payload[key] = MockUploadService.toMockUrl(value);
            }
          });

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
}
