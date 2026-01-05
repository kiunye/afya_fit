import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class ProgressRepository {
  final ApiClient _apiClient;

  ProgressRepository(this._apiClient);

  Future<List<Map<String, dynamic>>> getProgressEntries(String clientId) async {
    final response = await _apiClient.get(
      ApiConstants.clientProgress(clientId),
    );
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  // Get current user's progress entries (for clients)
  Future<List<Map<String, dynamic>>> getMyProgress() async {
    final response = await _apiClient.get(ApiConstants.meProgress);
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  // Create progress entry for current user (for clients)
  Future<Map<String, dynamic>> createMyProgressEntry(
    Map<String, dynamic> progressData,
  ) async {
    return await _apiClient.post(
      ApiConstants.meProgress,
      body: {'progress_entry': progressData},
    );
  }

  Future<Map<String, dynamic>> getProgressEntry(String id) async {
    return await _apiClient.get(ApiConstants.progress(id));
  }

  Future<Map<String, dynamic>> createProgressEntry(
    String clientId,
    Map<String, dynamic> progressData,
  ) async {
    return await _apiClient.post(
      ApiConstants.clientProgress(clientId),
      body: {'progress_entry': progressData},
    );
  }

  Future<Map<String, dynamic>> updateProgressEntry(
    String id,
    Map<String, dynamic> progressData,
  ) async {
    return await _apiClient.put(
      ApiConstants.progress(id),
      body: {'progress_entry': progressData},
    );
  }

  Future<void> deleteProgressEntry(String id) async {
    await _apiClient.delete(ApiConstants.progress(id));
  }

  Future<Map<String, dynamic>> getAnalytics(String clientId) async {
    return await _apiClient.get(
      ApiConstants.progressAnalytics(clientId),
    );
  }
}
