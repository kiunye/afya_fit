import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/tasks/data/repositories/task_repository.dart';

part 'task_provider.g.dart';

@riverpod
TaskRepository taskRepository(Ref ref) {
  return TaskRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> tasks(Ref ref) async {
  final repository = ref.read(taskRepositoryProvider);
  return repository.getTasks();
}

@riverpod
Future<List<Map<String, dynamic>>> clientTasks(
  Ref ref,
  String clientId,
) async {
  final repository = ref.read(taskRepositoryProvider);
  return repository.getClientTasks(clientId);
}
