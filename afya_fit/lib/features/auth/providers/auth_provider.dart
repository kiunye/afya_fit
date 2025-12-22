import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afya_fit/core/providers/api_provider.dart';

part 'auth_provider.g.dart';

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<bool> build() async {
    // Check if user is authenticated by checking for stored token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token != null && token.isNotEmpty;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.login(email, password);
      
      // Verify token was stored
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null && token.isNotEmpty) {
        state = const AsyncValue.data(true);
      } else {
        throw Exception('Login failed: No token received');
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.clearAuthToken();
      state = const AsyncValue.data(false);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
