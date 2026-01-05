import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/auth/data/models/user_model.dart';
import 'package:afya_fit/features/auth/data/repositories/auth_repository.dart';

part 'user_provider.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  final apiClient = ref.read(apiClientProvider);
  return AuthRepository(apiClient);
}

@riverpod
Future<UserModel?> currentUser(Ref ref) async {
  final repository = ref.read(authRepositoryProvider);
  return await repository.getCurrentUser();
}

