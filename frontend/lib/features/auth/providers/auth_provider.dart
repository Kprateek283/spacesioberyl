import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../../../core/network/api_client.dart';

// State model
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final bool sessionUnlocked;
  final String? userRole;
  final bool isGhostMode;
  final bool needsPinSetup;

  AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.sessionUnlocked = false,
    this.userRole,
    this.isGhostMode = false,
    this.needsPinSetup = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? sessionUnlocked,
    String? userRole,
    bool? isGhostMode,
    bool? needsPinSetup,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      sessionUnlocked: sessionUnlocked ?? this.sessionUnlocked,
      userRole: userRole ?? this.userRole,
      isGhostMode: isGhostMode ?? this.isGhostMode,
      needsPinSetup: needsPinSetup ?? this.needsPinSetup,
    );
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;
  final _storage = const FlutterSecureStorage();

  AuthNotifier(this._apiClient) : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _storage.read(key: 'jwt');
      final userString = await _storage.read(key: 'user_data');
      final pinsSetup = await _storage.read(key: 'pins_setup');

      if (token != null && !JwtDecoder.isExpired(token) && userString != null) {
        final userData = jsonDecode(userString);
        final decodedToken = JwtDecoder.decode(token);

        final ghostMode = decodedToken['ghost_mode'] == true;
        final roleValue = (userData['role'] ?? userData['role_name'] ?? 'staff')
            .toString()
            .toLowerCase();
        final requiresPinSetup = pinsSetup != 'true';

        state = state.copyWith(
          isAuthenticated: true,
          sessionUnlocked: roleValue != 'super_admin', // Only super_admin uses PINs
          userRole: roleValue,
          isGhostMode: ghostMode,
          needsPinSetup: requiresPinSetup,
          isLoading: false,
        );
      } else {
        state = AuthState(isLoading: false);
      }
    } catch (e) {
      state = AuthState(isLoading: false);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.post(
        '/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        // Backend returns `access_token`, `refresh_token`, and `user` on login
        final accessToken = response.data['access_token'];
        final refreshToken = response.data['refresh_token'];
        final user = response.data['user'];
        final requiresPinSetup = response.data['requires_pin_setup'] == true;

        if (accessToken != null) {
          await _storage.write(key: 'jwt', value: accessToken);
        }
        if (refreshToken != null) {
          await _storage.write(key: 'refresh_token', value: refreshToken);
        }
        if (user != null) {
          await _storage.write(key: 'user_data', value: jsonEncode(user));
        }
        if (requiresPinSetup) {
          await _storage.delete(key: 'pins_setup');
        } else {
          await _storage.write(key: 'pins_setup', value: 'true');
        }

        final roleName = (user != null)
            ? (user['role'] ?? user['role_name'] ?? 'staff')
                .toString()
                .toLowerCase()
            : 'staff';

        state = state.copyWith(
          isAuthenticated: true,
          sessionUnlocked: roleName != 'super_admin', // Only super_admin uses PINs
          userRole: roleName,
          needsPinSetup: requiresPinSetup,
          isLoading: false,
        );
      } else {
        throw Exception('Login failed. Please check your credentials.');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> setupPins(String normalPin, String highSecurityPin) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.post('/iam/setup-pins', data: {
        'normal_pin': normalPin,
        'confirm_normal_pin': normalPin,
        'high_security_pin': highSecurityPin,
        'confirm_high_security_pin': highSecurityPin,
      });

      if (response.statusCode == 200) {
        await _storage.write(key: 'pins_setup', value: 'true');
        state = state.copyWith(needsPinSetup: false, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> verifyPin(String pin) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.post('/iam/verify-pin', data: {
        'pin': pin,
      });

      if (response.statusCode == 200) {
        // Backend returns access_token and ghost_mode
        final newToken = response.data['access_token'];
        final ghostMode = response.data['ghost_mode'] == true;

        if (newToken != null) {
          await _storage.write(key: 'jwt', value: newToken);
        }

        // Ensure ghost mode is set if backend explicitly returned it
        state = state.copyWith(
          sessionUnlocked: true,
          isGhostMode: ghostMode,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    state = AuthState(isLoading: false); // Switch UI immediately back to signed-out mode

    try {
      await _apiClient.post('/logout'); // Inform backend if required
    } catch (_) {}
    
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'pins_setup');
  }
}
