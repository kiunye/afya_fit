import 'package:afya_fit/core/api/api_client.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class NutritionRepository {
  final ApiClient _apiClient;

  NutritionRepository(this._apiClient);

  Future<List<Map<String, dynamic>>> getNutritionPlans() async {
    final response = await _apiClient.get(ApiConstants.nutritionPlans());
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }

  Future<Map<String, dynamic>> getNutritionPlan(String id) async {
    return await _apiClient.get(ApiConstants.nutritionPlan(id));
  }

  Future<Map<String, dynamic>> createNutritionPlan(
    Map<String, dynamic> nutritionPlan,
  ) async {
    return await _apiClient.post(
      ApiConstants.nutritionPlans(),
      body: {'nutrition_plan': nutritionPlan},
    );
  }

  Future<Map<String, dynamic>> updateNutritionPlan(
    String id,
    Map<String, dynamic> nutritionPlan,
  ) async {
    return await _apiClient.put(
      ApiConstants.nutritionPlan(id),
      body: {'nutrition_plan': nutritionPlan},
    );
  }

  Future<void> deleteNutritionPlan(String id) async {
    await _apiClient.delete(ApiConstants.nutritionPlan(id));
  }
}
