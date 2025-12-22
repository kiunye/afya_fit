import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class TaskRepository {
  final ApiClient _apiClient;

  TaskRepository(this._apiClient);

  Future<List<Map<String, dynamic>>> getTasks() async {
    final response = await _apiClient.get(ApiConstants.tasks());
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  Future<List<Map<String, dynamic>>> getClientTasks(String clientId) async {
    final response = await _apiClient.get(
      ApiConstants.clientTasks(clientId),
    );
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  Future<Map<String, dynamic>> getTask(String id) async {
    return await _apiClient.get(ApiConstants.task(id));
  }

  Future<Map<String, dynamic>> createTask(
    Map<String, dynamic> taskData,
  ) async {
    return await _apiClient.post(
      ApiConstants.tasks(),
      body: {'task': taskData},
    );
  }

  Future<Map<String, dynamic>> updateTask(
    String id,
    Map<String, dynamic> taskData,
  ) async {
    return await _apiClient.put(
      ApiConstants.task(id),
      body: {'task': taskData},
    );
  }

  Future<void> deleteTask(String id) async {
    await _apiClient.delete(ApiConstants.task(id));
  }

  Future<Map<String, dynamic>> completeTask(String id) async {
    return await _apiClient.post(
      ApiConstants.taskComplete(id),
    );
  }
}
