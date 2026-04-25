import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class HrService {
  final String baseUrl = 'http://localhost:8080/api/v1/hr'; // Adjust if using Android emulator (10.0.2.2)
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  // Helper method to inject the JWT token into request headers
  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'jwt');
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
  }

  // Helper method to extract clean error messages from the Go backend
  String _handleError(DioException e) {
    if (e.response != null && e.response?.data is Map && e.response?.data['error'] != null) {
      return e.response?.data['error'];
    }
    return e.message ?? 'An unknown network error occurred';
  }

  // ==========================================
  // STAFF ENDPOINTS
  // ==========================================

  /// Hits POST /attendance/check-in
  Future<Map<String, dynamic>> checkIn() async {
    try {
      final response = await _dio.post(
        '$baseUrl/attendance/check-in',
        options: await _getAuthOptions(),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Hits POST /attendance/check-out
  Future<Map<String, dynamic>> checkOut() async {
    try {
      final response = await _dio.post(
        '$baseUrl/attendance/check-out',
        options: await _getAuthOptions(),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Hits POST /attendance/override
  Future<Map<String, dynamic>> submitOverride({
    String? startTime,
    String? endTime,
    String? reason,
  }) async {
    try {
      // The Go backend expects 'attendance_date' formatted as YYYY-MM-DD
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final data = {
        'attendance_date': today,
      };

      // Only attach these if the user actually typed them in
      if (startTime != null && startTime.isNotEmpty) data['requested_start_time'] = startTime;
      if (endTime != null && endTime.isNotEmpty) data['requested_end_time'] = endTime;
      if (reason != null && reason.isNotEmpty) data['employee_reason'] = reason;

      final response = await _dio.post(
        '$baseUrl/attendance/override',
        data: data,
        options: await _getAuthOptions(),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  // ==========================================
  // ADMIN ENDPOINTS
  // ==========================================

  /// Hits GET /attendance/report
  Future<List<dynamic>> getDailyReport() async {
    try {
      final response = await _dio.get(
        '$baseUrl/attendance/report',
        options: await _getAuthOptions(),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Hits GET /attendance/override/pending
  Future<List<dynamic>> getPendingOverrides() async {
    try {
      final response = await _dio.get(
        '$baseUrl/attendance/override/pending',
        options: await _getAuthOptions(),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Hits PATCH /attendance/override/{id}
  Future<void> reviewOverride(String overrideId, String status, {String? adminFeedback}) async {
    try {
      await _dio.patch(
        '$baseUrl/attendance/override/$overrideId',
        data: {
          'status': status,
          'admin_feedback': adminFeedback ?? '',
        },
        options: await _getAuthOptions(),
      );
    } on DioException catch (e) {
      throw Exception(_handleError(e));
    }
  }
}