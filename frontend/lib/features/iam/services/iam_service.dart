import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/api_parse.dart';

final iamServiceProvider = Provider<IamService>((ref) {
  return IamService(ref.watch(apiClientProvider));
});

class IamService {
  final ApiClient _api;

  IamService(this._api);

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _api.getUsers();
    return ApiParse.asMapList(response.data);
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    required String department,
  }) async {
    await _api.createUser(
      name: name,
      email: email,
      password: password,
      role: role,
      department: department,
    );
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.getMe();
    return ApiParse.asMap(response.data);
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _api.changePassword(oldPassword, newPassword);
  }
}
