import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/workouts/data/repositories/workout_repository.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/core/access/access_provider.dart';

part 'workout_provider.g.dart';

@riverpod
WorkoutRepository workoutRepository(Ref ref) {
  return WorkoutRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> workoutPlans(Ref ref) async {
  final repository = ref.read(workoutRepositoryProvider);
  final access = ref.watch(accessProvider);

  // Clients read their own assignments; coaches read the plan library.
  return access.role == AccessRole.client
      ? repository.getMyWorkouts()
      : repository.getWorkoutPlans();
}

@riverpod
Future<Map<String, dynamic>> workoutPlan(Ref ref, String id) async {
  final repository = ref.read(workoutRepositoryProvider);
  final response = await repository.getWorkoutPlan(id);
  return response['data'] as Map<String, dynamic>? ?? {};
}
