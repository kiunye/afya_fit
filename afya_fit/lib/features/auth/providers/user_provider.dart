import 'package:flutter_riverpod/flutter_riverpod.dart' show FutureProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/auth/data/models/session.dart';
import 'package:afya_fit/features/auth/data/models/user_model.dart';
import 'package:afya_fit/features/auth/data/repositories/auth_repository.dart';

part 'user_provider.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  final apiClient = ref.read(apiClientProvider);
  return AuthRepository(apiClient);
}

/// The signed-in user and what they may do. Invalidate it after login, logout or
/// a 402 so the app picks up the account's current state.
final sessionProvider = FutureProvider<Session?>((ref) {
  return ref.read(authRepositoryProvider).getSession();
});

@riverpod
Future<UserModel?> currentUser(Ref ref) async {
  final session = await ref.watch(sessionProvider.future);
  return session?.user;
}
