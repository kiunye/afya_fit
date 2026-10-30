import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/access/api_errors.dart';
import 'package:afya_fit/features/nutrition/providers/nutrition_provider.dart';

class NutritionFormScreen extends HookConsumerWidget {
  final String? nutritionPlanId;
  final Map<String, dynamic>? nutritionPlan;

  const NutritionFormScreen({
    super.key,
    this.nutritionPlanId,
    this.nutritionPlan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = nutritionPlanId != null;
    final formKey = GlobalKey<FormState>();
    
    final nameController = TextEditingController(text: nutritionPlan?['name'] ?? '');
    final descriptionController = TextEditingController(text: nutritionPlan?['description'] ?? '');
    final dailyCaloriesController = TextEditingController(
      text: nutritionPlan?['daily_calories']?.toString() ?? '',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Nutrition Plan' : 'Create Nutrition Plan'),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Plan Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter plan name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: dailyCaloriesController,
                decoration: const InputDecoration(
                  labelText: 'Daily Calories',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter daily calories';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      final nutritionData = {
                        'name': nameController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'daily_calories': int.parse(dailyCaloriesController.text),
                      };

                      if (isEditing && nutritionPlanId != null) {
                        await ref.read(nutritionRepositoryProvider).updateNutritionPlan(
                              nutritionPlanId!,
                              nutritionData,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nutrition plan updated successfully')),
                          );
                          Navigator.pop(context);
                        }
                      } else {
                        await ref.read(nutritionRepositoryProvider).createNutritionPlan(nutritionData);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nutrition plan created successfully')),
                          );
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      await showApiError(context, ref, e);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditing ? 'Update Nutrition Plan' : 'Create Nutrition Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

