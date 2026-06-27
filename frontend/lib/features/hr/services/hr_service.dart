import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/mock_upload_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/file_helper.dart';

final hrServiceProvider = Provider<HrService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final syncService = ref.watch(syncServiceProvider);
  return HrService(apiClient, syncService);
});

class HrService {
  final ApiClient _apiClient;
  final SyncService _syncService;

  HrService(this._apiClient, this._syncService);

  // ==========================================
  // ATTENDANCE
  // ==========================================

  Future<void> checkIn() async {
    await _apiClient.post('/hr/attendance/check-in');
  }

  Future<void> checkOut() async {
    await _apiClient.post('/hr/attendance/check-out');
  }

  Future<void> submitOverrideRequest(String reason) async {
    // We queue this as a mutation for offline support
    final payload = jsonEncode({
      'is_override_request': true,
      'override_reason': reason,
    });

    await DatabaseHelper.instance.queueMutation(
      endpoint: '/hr/attendance/check-in',
      method: 'POST',
      payload: payload,
    );

    // Trigger sync immediately if online
    await _syncService.triggerManualSync();
  }

  Future<dynamic> getMyAttendance() async {
    final response = await _apiClient.get('/hr/attendance/me');
    return response.data;
  }

  Future<List<dynamic>> getDailyReport() async {
    final response = await _apiClient.get('/hr/attendance');
    final data = response.data;
    if (data is List) {
      return List<dynamic>.from(data);
    }
    return const [];
  }

  Future<List<dynamic>> getPendingOverrides() async {
    final response = await _apiClient.get('/hr/attendance/overrides');
    final data = response.data;
    if (data is List) {
      return List<dynamic>.from(data);
    }
    return const [];
  }

  Future<void> reviewOverride(
    String overrideId,
    String status, {
    String? adminFeedback,
  }) async {
    await _apiClient.patch('/hr/attendance/overrides/$overrideId', data: {
      'status': status,
      if (status == 'rejected' && adminFeedback != null && adminFeedback.isNotEmpty)
        'rejected_reason': adminFeedback,
    });
  }

  // ==========================================
  // LEAVES
  // ==========================================

  Future<void> requestLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    final payload = jsonEncode({
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
    });

    await DatabaseHelper.instance.queueMutation(
      endpoint: '/hr/leaves',
      method: 'POST',
      payload: payload,
    );

    await _syncService.triggerManualSync();
  }

  Future<dynamic> getMyLeaves() async {
    final response = await _apiClient.get('/hr/leaves/me');
    return response.data;
  }

  Future<void> cancelLeave(int leaveId) async {
    await _apiClient.patch('/hr/leaves/$leaveId/cancel');
  }

  Future<List<Map<String, dynamic>>> getAllLeaves({String? status}) async {
    final response = await _apiClient.getAllLeaves(status: status);
    return ApiParse.asMapList(response.data);
  }

  Future<void> updateLeaveStatus(int leaveId, String status, String adminRemarks) async {
    await _apiClient.patch('/hr/leaves/$leaveId/status', data: {
      'status': status,
      'admin_remarks': adminRemarks,
    });
  }

  // ==========================================
  // EXPENSES
  // ==========================================

  Future<void> createExpense({
    required double amount,
    required String personPaid,
    required String context,
    required String expenseDate,
    String? receiptImagePath,
  }) async {
    final payloadMap = {
      'amount': amount,
      'person_paid': personPaid,
      'context': context,
      'expense_date': expenseDate,
    };

    if (receiptImagePath != null) {
      final persistentPath = await FileHelper.persistFile(receiptImagePath);
      payloadMap['receipt_url'] = MockUploadService.toMockUrl(
        persistentPath ?? receiptImagePath,
        bucket: 'receipts',
      );
    }

    final payload = jsonEncode(payloadMap);

    await DatabaseHelper.instance.queueMutation(
      endpoint: '/hr/expenses',
      method: 'POST',
      payload: payload,
      hasFile: false,
    );

    await _syncService.triggerManualSync();
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final response = await _apiClient.getExpenses();
    return ApiParse.asMapList(response.data);
  }
}
