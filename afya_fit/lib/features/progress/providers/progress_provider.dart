import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/progress/data/repositories/progress_repository.dart';
import 'package:afya_fit/core/access/access_provider.dart';

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
  final access = await ref.watch(accessProvider.future);

  // Clients (or no client chosen) read their own entries.
  if (clientId.isEmpty || access.isClient) {
    return repository.getMyProgress();
  }
  return repository.getProgressEntries(clientId);
}

@riverpod
Future<Map<String, dynamic>> progressAnalytics(Ref ref, String clientId) async {
  final repository = ref.read(progressRepositoryProvider);
  return repository.getAnalytics(clientId);
}
