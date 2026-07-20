import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/local_db/database_helper.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/mock_upload_service.dart';
import '../../../core/network/sync_service.dart';
import '../../../core/utils/api_parse.dart';
import '../../../core/utils/file_helper.dart';

final executionServiceProvider = Provider<ExecutionService>((ref) {
  return ExecutionService(
    ref.watch(apiClientProvider),
    ref.watch(syncServiceProvider),
  );
});

class ExecutionService {
  final ApiClient _api;
  final SyncService _sync;

  ExecutionService(this._api, this._sync);

  Future<void> createInstaller({
    required String name,
    required String phone,
    required String expertiseArea,
    required double standardRate,
    String? preferredPaymentMode,
  }) async {
    await _api.post('/execution/installers', data: {
      'name': name,
      'phone': phone,
      'expertise_area': expertiseArea,
      'standard_rate': standardRate,
      if (preferredPaymentMode != null)
        'preferred_payment_mode': preferredPaymentMode,
    });
    await _refreshInstallersCache();
  }

  Future<List<Map<String, dynamic>>> getJobs({bool myTasksOnly = false}) async {
    final response =
        myTasksOnly ? await _api.getMyJobs() : await _api.getJobs();
    return ApiParse.asMapList(response.data);
  }

  Future<void> createInstallation({
    required int orderId,
    required int technicalManagerId,
  }) async {
    await _api.createInstallation(
      orderId: orderId,
      technicalManagerId: technicalManagerId,
    );
  }

  Future<void> assignInstallerToJob({
    required int jobId,
    required int installerId,
    required double agreedInstallerPrice,
    required String estimatedCompletionDate,
  }) async {
    await _api.assignInstallerToJob(
      jobId: jobId,
      installerId: installerId,
      agreedInstallerPrice: agreedInstallerPrice,
      estimatedCompletionDate: estimatedCompletionDate,
    );
  }

  Future<void> syncJobUpdate({
    required int jobId,
    required DateTime updateTime,
    required String notes,
    String? photoUrl,
  }) async {
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final persistentPhotoPath = await FileHelper.persistFile(photoUrl);
    final payload = {
      'updates': [
        {
          'local_id': localId,
          'update_time': updateTime.toUtc().toIso8601String(),
          'notes': notes,
          if (persistentPhotoPath != null) 'photo_url': persistentPhotoPath,
        },
      ],
    };

    await DatabaseHelper.instance.insertLocalSiteUpdate(
      jobId: jobId,
      localId: localId,
      notes: notes,
      updateTime: updateTime.toUtc().toIso8601String(),
      photoUrl: persistentPhotoPath,
    );

    await DatabaseHelper.instance.queueMutation(
      endpoint: '/execution/jobs/$jobId/updates/sync',
      method: 'POST',
      payload: jsonEncode(payload),
      hasFile: persistentPhotoPath != null,
      localFilePath: persistentPhotoPath,
      fileFieldKey: persistentPhotoPath != null ? 'updates.0.photo_url' : null,
    );
    await _sync.triggerManualSync();
  }

  Future<List<Map<String, dynamic>>> getJobUpdates(int jobId) async {
    final response = await _api.getSiteUpdates(jobId);
    return ApiParse.asMapList(response.data);
  }

  Future<void> recordClientSignoff({
    required int jobId,
    required String clientSignoffUrl,
    required String status,
    String? clientFeedback,
  }) async {
    final persistentPath =
        await FileHelper.persistFile(clientSignoffUrl) ?? clientSignoffUrl;
    final payload = {
      'status': status,
      if (clientFeedback != null && clientFeedback.isNotEmpty)
        'client_feedback': clientFeedback,
    };

    await DatabaseHelper.instance.queueMutation(
      endpoint: '/execution/jobs/$jobId/signoff',
      method: 'PATCH',
      payload: jsonEncode(payload),
      hasFile: true,
      localFilePath: persistentPath,
      fileFieldKey: 'client_signoff_url',
    );
    await _sync.triggerManualSync();
  }

  Future<Map<String, dynamic>> getContractorLedger(int jobId) async {
    final response = await _api.getContractorLedger(jobId);
    return ApiParse.asMap(response.data);
  }

  Future<void> recordContractorPayment({
    required int jobId,
    required double amount,
    required String paymentType,
    required String paymentMode,
    String? transactionReference,
  }) async {
    await _api.recordContractorPayment(
      jobId: jobId,
      amount: amount,
      paymentType: paymentType,
      paymentMode: paymentMode,
      transactionReference: transactionReference,
    );
  }

  Future<void> updateContractorJobStatus(int jobId, String status) async {
    await _api.updateContractorJobStatus(jobId, status);
  }

  Future<void> contractorCheckIn(int jobId, {String? verificationNotes, String? proofPhotoUrl}) async {
    String? mockUrl;
    if (proofPhotoUrl != null && proofPhotoUrl.isNotEmpty) {
      final persistentPath = await FileHelper.persistFile(proofPhotoUrl) ?? proofPhotoUrl;
      // TODO: replace with a real upload once a generic backend upload
      // endpoint exists (see issue/01-backend-issues.md).
      mockUrl = MockUploadService.toMockUrl(persistentPath, bucket: 'contractor-checkins');
    }
    await _api.contractorCheckIn(jobId, verificationNotes: verificationNotes, proofPhotoUrl: mockUrl);
  }

  Future<void> contractorCheckOut(int jobId) async {
    await _api.contractorCheckOut(jobId);
  }

  Future<void> _refreshInstallersCache() async {
    final response = await _api.getInstallers();
    await DatabaseHelper.instance.cacheInstallers(
      ApiParse.asMapList(response.data),
    );
  }
}
