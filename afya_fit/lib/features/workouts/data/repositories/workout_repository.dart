import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class WorkoutRepository {
  final ApiClient _apiClient;

  WorkoutRepository(this._apiClient);

  Future<List<Map<String, dynamic>>> getWorkoutPlans() async {
    final response = await _apiClient.get(ApiConstants.workoutPlans());
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  // Get current user's assigned workouts (for clients)
  Future<List<Map<String, dynamic>>> getMyWorkouts() async {
    final response = await _apiClient.get(ApiConstants.meWorkouts);
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  Future<Map<String, dynamic>> getWorkoutPlan(String id) async {
    return await _apiClient.get(ApiConstants.workoutPlan(id));
  }

  Future<Map<String, dynamic>> createWorkoutPlan(
    Map<String, dynamic> workoutPlan,
  ) async {
    return await _apiClient.post(
      ApiConstants.workoutPlans(),
      body: {'workout_plan': workoutPlan},
    );
  }

  Future<Map<String, dynamic>> updateWorkoutPlan(
    String id,
    Map<String, dynamic> workoutPlan,
  ) async {
    return await _apiClient.put(
      ApiConstants.workoutPlan(id),
      body: {'workout_plan': workoutPlan},
    );
  }

  Future<void> deleteWorkoutPlan(String id) async {
    await _apiClient.delete(ApiConstants.workoutPlan(id));
  }
}
