import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/workouts/data/repositories/workout_repository.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';

part 'workout_provider.g.dart';

@riverpod
WorkoutRepository workoutRepository(Ref ref) {
  return WorkoutRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> workoutPlans(Ref ref) async {
  final repository = ref.read(workoutRepositoryProvider);
  final userAsync = ref.read(currentUserProvider);
  
  // If user is a client, use /me/workouts endpoint
  return userAsync.when(
    data: (user) {
      if (user?.role == 'client') {
        return repository.getMyWorkouts();
      }
      return repository.getWorkoutPlans();
    },
    loading: () => repository.getWorkoutPlans(), // Fallback
    error: (_, __) => repository.getWorkoutPlans(), // Fallback
  );
}

@riverpod
Future<Map<String, dynamic>> workoutPlan(Ref ref, String id) async {
  final repository = ref.read(workoutRepositoryProvider);
  final response = await repository.getWorkoutPlan(id);
  return response['data'] as Map<String, dynamic>? ?? {};
}
