import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  static String get baseUrl =>
      dotenv.env['API_URL'] ?? 'http://localhost:8080/api/v1';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: dotenv.env['API_URL'] ?? 'http://localhost:8080/api/v1',
    connectTimeout: const Duration(seconds: 15),
  ));
  final _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;
  
  // A queue for saving requests that fail with 401 while refreshing is in progress
  final _retryQueue = <Future<Response> Function()>[];

  ApiClient() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Exclude login and refresh endpoints from token injection
          if (!options.path.contains('/login') && !options.path.contains('/refresh')) {
            final token = await _storage.read(key: 'jwt');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 && 
              !e.requestOptions.path.contains('/login') && 
              !e.requestOptions.path.contains('/refresh') &&
              !e.requestOptions.path.contains('/verify-pin')) {
            
            // Initiate Refresh Token Logic
            return await _handle401Error(e, handler);
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> _handle401Error(DioException e, ErrorInterceptorHandler handler) async {
    final refreshToken = await _storage.read(key: 'refresh_token');

    if (refreshToken == null) {
      // No refresh token available, force logout or let error propagate
      return handler.next(e);
    }

    if (!_isRefreshing) {
      _isRefreshing = true;

      try {
        final refreshDio = Dio(BaseOptions(
          baseUrl: baseUrl,
        ));
        final response = await refreshDio.post('/refresh', data: {
          'refresh_token': refreshToken,
        });

        if (response.statusCode == 200) {
          final newToken = response.data['access_token'];
          final newRefreshToken = response.data['refresh_token']; // If backend rotates it
          
          await _storage.write(key: 'jwt', value: newToken);
          if (newRefreshToken != null) {
             await _storage.write(key: 'refresh_token', value: newRefreshToken);
          }

          // Retry queued requests
          _isRefreshing = false;
          for (var retryReq in _retryQueue) {
            retryReq(); // Fire and forget or handle properly if complex
          }
          _retryQueue.clear();

          // Retry the original failed request
          final retryResponse = await _retryOriginalRequest(e.requestOptions, newToken);
          return handler.resolve(retryResponse);
        } else {
          _isRefreshing = false;
          return handler.next(e);
        }
      } catch (err) {
        _isRefreshing = false;
        // Refresh failed, probably expired. 
        await _storage.delete(key: 'jwt');
        await _storage.delete(key: 'refresh_token');
        return handler.next(e);
      }
    } else {
      // Already refreshing, queue the request
      _retryQueue.add(() async {
         final newToken = await _storage.read(key: 'jwt');
         return await _retryOriginalRequest(e.requestOptions, newToken!);
      });
    }
  }

  Future<Response<dynamic>> _retryOriginalRequest(RequestOptions requestOptions, String newToken) async {
      final options = Options(
        method: requestOptions.method,
        headers: {
          ...requestOptions.headers,
          'Authorization': 'Bearer $newToken',
        },
      );
      
      final dioRetry = Dio(BaseOptions(
        baseUrl: baseUrl,
      ));
      return dioRetry.request<dynamic>(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: options,
      );
  }

  // --- Convenience Methods ---
  
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) async {
    return _dio.patch(path, data: data);
  }
  
  Future<Response> delete(String path, {dynamic data}) async {
    return _dio.delete(path, data: data);
  }
  
  Future<Response> uploadFile(String path, String filePath, {Map<String, dynamic>? extraData}) async {
    String fileName = filePath.split('/').last;
    FormData formData = FormData.fromMap({
      if (extraData != null) ...extraData,
      "file": await MultipartFile.fromFile(filePath, filename: fileName),
    });
    return _dio.post(path, data: formData);
  }

  // --- IAM Endpoints ---
  Future<Response> setupPins(String normalPin, String highSecurityPin) {
    return post('/iam/setup-pins', data: {
      'normal_pin': normalPin,
      'confirm_normal_pin': normalPin,
      'high_security_pin': highSecurityPin,
      'confirm_high_security_pin': highSecurityPin,
    });
  }

  Future<Response> verifyPin(String pin) {
    return post('/iam/verify-pin', data: {'pin': pin});
  }

  Future<Response> refreshToken(String refreshToken) {
    return post('/refresh', data: {'refresh_token': refreshToken});
  }

  Future<Response> getMe() {
    return get('/users/me');
  }

  Future<Response> changePassword(String oldPassword, String newPassword) {
    return patch('/users/me/password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<Response> logout() {
    return post('/logout');
  }

  // --- HR Endpoints ---
  Future<Response> checkIn({bool isOverride = false, String? overrideReason}) {
    final data = isOverride
        ? {'is_override_request': true, 'override_reason': overrideReason}
        : {};
    return post('/hr/attendance/check-in', data: data);
  }

  Future<Response> checkOut() {
    return post('/hr/attendance/check-out');
  }

  Future<Response> getMyAttendance() {
    return get('/hr/attendance/me');
  }

  Future<Response> requestLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) {
    return post('/hr/leaves', data: {
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
    });
  }

  Future<Response> getMyLeaves() {
    return get('/hr/leaves/me');
  }

  Future<Response> updateLeave(int leaveId, {String? startDate, String? reason}) {
    return patch('/hr/leaves/$leaveId', data: {
      if (startDate != null) 'start_date': startDate,
      if (reason != null) 'reason': reason,
    });
  }

  Future<Response> cancelLeave(int leaveId) {
    return patch('/hr/leaves/$leaveId/cancel');
  }

  Future<Response> createExpense({
    required double amount,
    required String personPaid,
    required String context,
    required String expenseDate,
  }) {
    return post('/hr/expenses', data: {
      'amount': amount,
      'person_paid': personPaid,
      'context': context,
      'expense_date': expenseDate,
    });
  }

  // --- CRM Endpoints ---
  Future<Response> createLead({
    required String clientName,
    required String clientPhone,
    String? clientEmail,
    String? source,
  }) {
    return post('/crm/leads', data: {
      'client_name': clientName,
      'client_phone': clientPhone,
      'client_email': clientEmail,
      'source': source,
    });
  }

  Future<Response> getLeads({String? status}) {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return get('/crm/leads', queryParameters: params);
  }

  Future<Response> getLead(int leadId) {
    return get('/crm/leads/$leadId');
  }

  Future<Response> updateLeadStatus(int leadId, String status, {String? lostReason}) {
    return patch('/crm/leads/$leadId/status', data: {
      'status': status,
      if (lostReason != null) 'lost_reason': lostReason,
    });
  }

  Future<Response> assignLead(int leadId, int assignedTo) {
    return patch('/crm/leads/$leadId/assign', data: {'assigned_to': assignedTo});
  }

  Future<Response> createFollowup({
    required int leadId,
    required String scheduledFor,
    required String notes,
  }) {
    return post('/crm/followups', data: {
      'lead_id': leadId,
      'scheduled_for': scheduledFor,
      'notes': notes,
    });
  }

  Future<Response> getMyFollowupQueue() {
    return get('/crm/followups/my-queue');
  }

  Future<Response> completeFollowup(int followupId, String outcomeNotes) {
    return patch('/crm/followups/$followupId/complete', data: {
      'outcome_notes': outcomeNotes,
    });
  }

  Future<Response> createComplaint({
    required String title,
    required String description,
    required String priority,
    int? leadId,
    int? orderId,
    String? clientName,
    String? clientPhone,
  }) {
    return post('/crm/complaints', data: {
      'title': title,
      'description': description,
      'priority': priority,
      if (leadId != null) 'lead_id': leadId,
      if (orderId != null) 'order_id': orderId,
      if (clientName != null) 'client_name': clientName,
      if (clientPhone != null) 'client_phone': clientPhone,
    });
  }

  // --- Logistics Endpoints ---
  Future<Response> getVendors() {
    return get('/logistics/vendors');
  }

  Future<Response> recordDispatch({
    required int dispatchId,
    required String type,
    String? notes,
    String? challanUrl,
  }) {
    return patch('/logistics/dispatches/$dispatchId/log', data: {
      'type': type,
      if (notes != null) 'notes': notes,
      if (challanUrl != null) 'challan_url': challanUrl,
    });
  }

  // --- Execution Endpoints ---
  Future<Response> getInstallers() {
    return get('/execution/installers');
  }

  Future<Response> syncSiteUpdates({
    required int jobId,
    required List<Map<String, dynamic>> updates,
  }) {
    return post('/execution/jobs/$jobId/updates/sync', data: {
      'updates': updates,
    });
  }

  Future<Response> getSiteUpdates(int jobId) {
    return get('/execution/jobs/$jobId/updates');
  }

  Future<Response> recordClientSignoff({
    required int jobId,
    required String clientSignoffUrl,
    required String status,
    String? clientFeedback,
  }) {
    return patch('/execution/jobs/$jobId/signoff', data: {
      'client_signoff_url': clientSignoffUrl,
      'status': status,
      if (clientFeedback != null) 'client_feedback': clientFeedback,
    });
  }

  // --- IAM Users ---
  Future<Response> getUsers() => get('/users');

  Future<Response> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required String department,
  }) {
    return post('/users', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'department': department,
    });
  }

  // --- HR Admin ---
  Future<Response> getAllLeaves({String? status}) {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    return get('/hr/leaves', queryParameters: params);
  }

  Future<Response> updateLeaveStatusAdmin(
    int leaveId, {
    required String status,
    String? adminRemarks,
  }) {
    return patch('/hr/leaves/$leaveId/status', data: {
      'status': status,
      if (adminRemarks != null) 'admin_remarks': adminRemarks,
    });
  }

  Future<Response> getExpenses() => get('/hr/expenses');

  // --- CRM extended ---
  Future<Response> getComplaints() => get('/crm/complaints');

  Future<Response> updateComplaintStatus(int complaintId, String status) {
    return patch('/crm/complaints/$complaintId/status', data: {'status': status});
  }

  Future<Response> assignComplaint(int complaintId, int assignedTo) {
    return patch('/crm/complaints/$complaintId/assign',
        data: {'assigned_to': assignedTo});
  }

  Future<Response> getLeadQuotations(int leadId) =>
      get('/crm/leads/$leadId/quotations');

  Future<Response> createQuotation({
    required int leadId,
    required String paymentTermType,
    required double taxRate,
    required List<Map<String, dynamic>> lineItems,
  }) {
    return post('/crm/leads/$leadId/quotations', data: {
      'payment_term_type': paymentTermType,
      'tax_rate': taxRate,
      'line_items': lineItems,
    });
  }

  Future<Response> updateQuotationStatus(int quotationId, String status) {
    return patch('/crm/quotations/$quotationId/status', data: {'status': status});
  }

  // --- Logistics extended ---
  Future<Response> getOrders() => get('/logistics/orders');

  Future<Response> assignOrderManager(int orderId, int operationsManagerId) {
    return patch('/logistics/orders/$orderId/assign',
        data: {'operations_manager_id': operationsManagerId});
  }

  Future<Response> createPurchaseOrder({
    required int orderId,
    required int vendorId,
    required double totalAmount,
    required String expectedDeliveryDate,
  }) {
    return post('/logistics/orders/$orderId/pos', data: {
      'vendor_id': vendorId,
      'total_amount': totalAmount,
      'expected_delivery_date': expectedDeliveryDate,
    });
  }

  Future<Response> getMyDispatches() => get('/logistics/dispatches/my-tasks');

  Future<Response> createDispatch({
    required int orderId,
    required int operationsStaffId,
    required String loadingResponsibility,
    String? transportDriverName,
    String? transportVehicleNo,
  }) {
    return post('/logistics/dispatches', data: {
      'order_id': orderId,
      'operations_staff_id': operationsStaffId,
      'loading_responsibility': loadingResponsibility,
      if (transportDriverName != null)
        'transport_driver_name': transportDriverName,
      if (transportVehicleNo != null)
        'transport_vehicle_no': transportVehicleNo,
    });
  }

  // --- Execution extended ---
  Future<Response> getJobs() => get('/execution/jobs');

  Future<Response> getMyJobs() => get('/execution/jobs/my-tasks');

  Future<Response> createInstallation({
    required int orderId,
    required int technicalManagerId,
  }) {
    return post('/execution/orders/$orderId/installation', data: {
      'technical_manager_id': technicalManagerId,
    });
  }

  Future<Response> assignInstallerToJob({
    required int jobId,
    required int installerId,
    required double agreedInstallerPrice,
    required String estimatedCompletionDate,
  }) {
    return patch('/execution/jobs/$jobId/assign', data: {
      'installer_id': installerId,
      'agreed_installer_price': agreedInstallerPrice,
      'estimated_completion_date': estimatedCompletionDate,
    });
  }

  Future<Response> updateContractorJobStatus(int jobId, String status) {
    return patch('/execution/contractors/jobs/$jobId/status',
        data: {'status': status});
  }

  Future<Response> contractorCheckIn(int jobId,
      {String? verificationNotes, String? proofPhotoUrl}) {
    return post('/execution/contractors/jobs/$jobId/check-in', data: {
      if (verificationNotes != null) 'verification_notes': verificationNotes,
      if (proofPhotoUrl != null) 'proof_photo_url': proofPhotoUrl,
    });
  }

  Future<Response> contractorCheckOut(int jobId) =>
      post('/execution/contractors/jobs/$jobId/check-out');

  Future<Response> recordContractorPayment({
    required int jobId,
    required double amount,
    required String paymentType,
    required String paymentMode,
    String? transactionReference,
  }) {
    return post('/execution/contractors/jobs/$jobId/payments', data: {
      'amount': amount,
      'payment_type': paymentType,
      'payment_mode': paymentMode,
      if (transactionReference != null)
        'transaction_reference': transactionReference,
    });
  }

  Future<Response> getContractorLedger(int jobId) =>
      get('/execution/contractors/jobs/$jobId/ledger');
}
