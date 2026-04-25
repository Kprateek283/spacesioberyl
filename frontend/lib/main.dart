import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

// Updated import paths to match our new folder structure
import 'screens/auth/login_screen.dart';
import 'screens/staff/staff_home_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

void main() {
  runApp(const StudioCRMApp());
}

class StudioCRMApp extends StatelessWidget {
  const StudioCRMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Studio CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFEF9F2),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String _userRole = 'staff'; // Default fallback

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.read(key: 'jwt');
    final userString = await _storage.read(key: 'user_data');

    if (token != null && !JwtDecoder.isExpired(token) && userString != null) {
      final userData = jsonDecode(userString);
      setState(() {
        _isAuthenticated = true;
        _userRole = userData['role_name'] ?? 'staff';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0061a4))),
      );
    }

    // If not authenticated, go to Login
    if (!_isAuthenticated) {
      return const LoginScreen();
    }

    // If authenticated, route based on role!
    if (_userRole == 'super_admin' || _userRole == 'admin') {
      return const AdminDashboardScreen();
    }

    return const StaffHomeScreen();
  }
}