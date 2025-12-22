import 'package:afya_fit/core/api/api_client.dart';
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

  Future<UserModel?> getCurrentUser() async {
    // TODO: Implement get current user endpoint
    return null;
  }
}
