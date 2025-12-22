import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/progress/data/repositories/progress_repository.dart';

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
  return repository.getProgressEntries(clientId);
}

@riverpod
Future<Map<String, dynamic>> progressAnalytics(
  Ref ref,
  String clientId,
) async {
  final repository = ref.read(progressRepositoryProvider);
  return repository.getAnalytics(clientId);
}
