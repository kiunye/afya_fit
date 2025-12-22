import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/constants/api_constants.dart';
import '../models/dashboard_stats.dart';

class DashboardRepository {
  final ApiClient _apiClient;

  DashboardRepository(this._apiClient);

  // For now, we'll aggregate stats from multiple endpoints
  // In the future, the backend might provide a dedicated dashboard endpoint
  Future<DashboardStats> getStats() async {
    try {
      // Fetch clients
      final clientsResponse = await _apiClient.get(ApiConstants.clients());
      final clients = List<Map<String, dynamic>>.from(
        clientsResponse['data'] ?? [],
      );

      // Fetch workout plans
      final workoutsResponse = await _apiClient.get(
        ApiConstants.workoutPlans(),
      );
      final workouts = List<Map<String, dynamic>>.from(
        workoutsResponse['data'] ?? [],
      );

      // Fetch nutrition plans
      final nutritionResponse = await _apiClient.get(
        ApiConstants.nutritionPlans(),
      );
      final nutrition = List<Map<String, dynamic>>.from(
        nutritionResponse['data'] ?? [],
      );

      // Fetch tasks
      final tasksResponse = await _apiClient.get(ApiConstants.tasks());
      final tasks = List<Map<String, dynamic>>.from(
        tasksResponse['data'] ?? [],
      );
      final activeTasks = tasks.where((task) {
        final status = task['status'] as String?;
        return status == 'pending' || status == 'in_progress';
      }).length;

      // Fetch calendar events
      final calendarResponse = await _apiClient.get(
        ApiConstants.calendarUpcoming(),
      );
      final events = List<Map<String, dynamic>>.from(
        calendarResponse['data'] ?? [],
      );

      return DashboardStats(
        totalClients: clients.length,
        totalWorkoutPlans: workouts.length,
        totalNutritionPlans: nutrition.length,
        activeTasks: activeTasks,
        upcomingEvents: events.length,
        recentProgressEntries: 0, // TODO: Implement when progress endpoint is ready
      );
    } catch (e) {
      // Return empty stats on error
      return const DashboardStats(
        totalClients: 0,
        totalWorkoutPlans: 0,
        totalNutritionPlans: 0,
        activeTasks: 0,
        upcomingEvents: 0,
        recentProgressEntries: 0,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getRecentClients({int limit = 5}) async {
    final response = await _apiClient.get(ApiConstants.clients());
    final clients = List<Map<String, dynamic>>.from(
      response['data'] ?? [],
    );
    return clients.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getRecentWorkouts({int limit = 5}) async {
    final response = await _apiClient.get(ApiConstants.workoutPlans());
    final workouts = List<Map<String, dynamic>>.from(
      response['data'] ?? [],
    );
    return workouts.take(limit).toList();
  }
}
