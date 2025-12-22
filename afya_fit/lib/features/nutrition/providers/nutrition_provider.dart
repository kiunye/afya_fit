import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/nutrition/data/repositories/nutrition_repository.dart';

part 'nutrition_provider.g.dart';

@riverpod
NutritionRepository nutritionRepository(Ref ref) {
  return NutritionRepository(ref.read(apiClientProvider));
}

@riverpod
Future<List<Map<String, dynamic>>> nutritionPlans(Ref ref) async {
  final repository = ref.read(nutritionRepositoryProvider);
  return repository.getNutritionPlans();
}
