import 'dart:convert'; // Add this at the top
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  final String baseUrl = 'http://localhost:8080/api/v1'; // Or 10.0.2.2 for Android
  final Dio _dio = Dio();
  final _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '$baseUrl/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final user = response.data['user'];

        // Save BOTH the token and the user JSON string to storage
        await _storage.write(key: 'jwt', value: token);
        await _storage.write(key: 'user_data', value: jsonEncode(user));

        return user;
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Login failed');
    }
    return null;
  }

  // Rename and update this to pull from our saved JSON instead of the JWT
  Future<Map<String, dynamic>?> getSavedUserData() async {
    final token = await _storage.read(key: 'jwt');

    // Still check if the token exists and is valid
    if (token != null && !JwtDecoder.isExpired(token)) {
      final userString = await _storage.read(key: 'user_data');
      if (userString != null) {
        return jsonDecode(userString); // Convert string back to a Map
      }
    }
    return null;
  }

  Future<void> logout() async {
    // Clear everything on logout
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'user_data');
  }

  // --- ADD THIS METHOD ---
  Future<void> createUser(String username, String password, int roleId, int? departmentId) async {
    try {
      // 1. Get the saved token
      final token = await _storage.read(key: 'jwt');

      // 2. Send the request with the token in the Authorization header
      await _dio.post(
        '$baseUrl/users',
        data: {
          'username': username,
          'password': password,
          'role_id': roleId,
          'department_id': departmentId,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['error'] ?? 'Failed to create user');
    }
  }
}