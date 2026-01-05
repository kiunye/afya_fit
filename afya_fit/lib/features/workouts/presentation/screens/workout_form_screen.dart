import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/features/workouts/providers/workout_provider.dart';

class WorkoutFormScreen extends HookConsumerWidget {
  final String? workoutId;
  final Map<String, dynamic>? workout;

  const WorkoutFormScreen({
    super.key,
    this.workoutId,
    this.workout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = workoutId != null;
    final formKey = GlobalKey<FormState>();
    
    final nameController = TextEditingController(text: workout?['name'] ?? '');
    final descriptionController = TextEditingController(text: workout?['description'] ?? '');
    final durationController = TextEditingController(
      text: workout?['duration_weeks']?.toString() ?? '',
    );
    
    String selectedDifficulty = workout?['difficulty'] ?? 'beginner';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Workout Plan' : 'Create Workout Plan'),
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
                  labelText: 'Workout Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter workout name';
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
                controller: durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration (weeks)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter duration';
                  }
                  if (int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedDifficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                  DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedDifficulty = value;
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      final workoutData = {
                        'name': nameController.text.trim(),
                        'description': descriptionController.text.trim(),
                        'duration_weeks': int.parse(durationController.text),
                        'difficulty': selectedDifficulty,
                      };

                      if (isEditing && workoutId != null) {
                        await ref.read(workoutRepositoryProvider).updateWorkoutPlan(
                              workoutId!,
                              workoutData,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workout plan updated successfully')),
                          );
                          Navigator.pop(context);
                        }
                      } else {
                        await ref.read(workoutRepositoryProvider).createWorkoutPlan(workoutData);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workout plan created successfully')),
                          );
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditing ? 'Update Workout Plan' : 'Create Workout Plan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

