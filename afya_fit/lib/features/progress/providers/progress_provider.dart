import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/progress/data/repositories/progress_repository.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';

part 'progress_provider.g.dart';

@riverpod
ProgressRepository progressRepository(Ref ref) {
  return ProgressRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> progressEntries(
  Ref ref,
  String clientId,
) async {
  final repository = ref.read(progressRepositoryProvider);
  final userAsync = ref.read(currentUserProvider);
  
  // If clientId is empty or user is a client, use /me/progress endpoint
  return userAsync.when(
    data: (user) {
      if (clientId.isEmpty || user?.role == 'client') {
        return repository.getMyProgress();
      }
      return repository.getProgressEntries(clientId);
    },
    loading: () {
      if (clientId.isEmpty) {
        return repository.getMyProgress();
      }
      return repository.getProgressEntries(clientId);
    },
    error: (_, __) {
      if (clientId.isEmpty) {
        return repository.getMyProgress();
      }
      return repository.getProgressEntries(clientId);
    },
  );
}

@riverpod
Future<Map<String, dynamic>> progressAnalytics(
  Ref ref,
  String clientId,
) async {
  final repository = ref.read(progressRepositoryProvider);
  return repository.getAnalytics(clientId);
}
