import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/features/auth/data/models/session.dart';
import 'package:afya_fit/features/auth/data/models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<UserModel> login(String email, String password) async {
    final response = await _apiClient.login(email, password);

    // The API returns: { "data": { ...user... }, "token": "..." }
    Map<String, dynamic>? userData;

    if (response.containsKey('data')) {
      userData = response['data'] as Map<String, dynamic>?;
    } else if (response.containsKey('user')) {
      userData = response['user'] as Map<String, dynamic>?;
    }

    if (userData != null) {
      return UserModel.fromJson(userData);
    }

    // Fallback: create user from email if API doesn't return user data
    return UserModel(
      id: response['id']?.toString() ?? '1',
      email: email,
      name: response['name'] as String?,
      role: response['role'] as String? ?? 'client',
      organizationId: response['organization_id']?.toString(),
    );
  }

  Future<void> logout() async {
    await _apiClient.clearAuthToken();
  }

  /// The signed-in user and what they may do, from one `/auth/me` call. Older
  /// servers do not send `access`; permissions then come from the legacy role.
  Future<Session?> getSession() async {
    try {
      final response = await _apiClient.getCurrentUser();

      // The API returns: { "data": { ...user... }, "access": { ... } }
      final userData =
          (response['data'] ?? response['user']) as Map<String, dynamic>?;
      if (userData == null) return null;

      final user = UserModel.fromJson(userData);
      final accessData = response['access'] as Map<String, dynamic>?;
      final access = accessData == null
          ? Access.legacy(user.role)
          : Access.fromJson(accessData);

      return Session(user: user, access: access);
    } catch (e) {
      return null;
    }
  }

  Future<UserModel?> getCurrentUser() async => (await getSession())?.user;
}
