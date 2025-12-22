import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/workouts/data/repositories/workout_repository.dart';

part 'workout_provider.g.dart';

@riverpod
WorkoutRepository workoutRepository(Ref ref) {
  return WorkoutRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> workoutPlans(Ref ref) async {
  final repository = ref.read(workoutRepositoryProvider);
  return repository.getWorkoutPlans();
}
