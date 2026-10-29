import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/nutrition/data/repositories/nutrition_repository.dart';
import 'package:afya_fit/core/access/access_provider.dart';

part 'nutrition_provider.g.dart';

@riverpod
NutritionRepository nutritionRepository(Ref ref) {
  return NutritionRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> nutritionPlans(Ref ref) async {
  final repository = ref.read(nutritionRepositoryProvider);
  final access = await ref.watch(accessProvider.future);

  // Clients read their own plans; coaches read the plans they manage.
  return access.isClient
      ? repository.getMyNutrition()
      : repository.getNutritionPlans();
}

@riverpod
Future<Map<String, dynamic>> nutritionPlan(Ref ref, String id) async {
  final repository = ref.read(nutritionRepositoryProvider);
  final response = await repository.getNutritionPlan(id);
  return response['data'] as Map<String, dynamic>? ?? {};
}
