import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';

part 'nutrition_provider.g.dart';

@riverpod
NutritionRepository nutritionRepository(Ref ref) {
  return NutritionRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> nutritionPlans(Ref ref) async {
  final repository = ref.read(nutritionRepositoryProvider);
  final userAsync = ref.read(currentUserProvider);
  
  // If user is a client, use /me/nutrition endpoint
  return userAsync.when(
    data: (user) {
      if (user?.role == 'client') {
        return repository.getMyNutrition();
      }
      return repository.getNutritionPlans();
    },
    loading: () => repository.getNutritionPlans(), // Fallback
    error: (_, __) => repository.getNutritionPlans(), // Fallback
  );
}

@riverpod
Future<Map<String, dynamic>> nutritionPlan(Ref ref, String id) async {
  final repository = ref.read(nutritionRepositoryProvider);
  final response = await repository.getNutritionPlan(id);
  return response['data'] as Map<String, dynamic>? ?? {};
}
