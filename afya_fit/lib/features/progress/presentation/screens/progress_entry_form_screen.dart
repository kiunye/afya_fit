import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/access/api_errors.dart';
import 'package:afya_fit/features/progress/providers/progress_provider.dart';
import 'package:intl/intl.dart';

class ProgressEntryFormScreen extends HookConsumerWidget {
  const ProgressEntryFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final weightController = TextEditingController();
    final bodyFatController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? selectedDate = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Progress Entry'),
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Picker
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(selectedDate!),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate!,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      selectedDate = picked;
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Weight
              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                  helperText: 'Optional',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final weight = double.tryParse(value);
                    if (weight == null || weight <= 0) {
                      return 'Please enter a valid weight';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Body Fat
              TextFormField(
                controller: bodyFatController,
                decoration: const InputDecoration(
                  labelText: 'Body Fat Percentage (%)',
                  border: OutlineInputBorder(),
                  helperText: 'Optional',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final bodyFat = double.tryParse(value);
                    if (bodyFat == null || bodyFat < 0 || bodyFat > 100) {
                      return 'Please enter a valid percentage (0-100)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Notes
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                  helperText: 'Optional',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      final progressData = {
                        'date': selectedDate!.toIso8601String().split('T')[0],
                        if (weightController.text.isNotEmpty)
                          'weight': double.parse(weightController.text),
                        if (bodyFatController.text.isNotEmpty)
                          'body_fat_percentage': double.parse(bodyFatController.text),
                        if (notesController.text.isNotEmpty)
                          'notes': notesController.text.trim(),
                      };

                      final repository = ref.read(progressRepositoryProvider);
                      await repository.createMyProgressEntry(progressData);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Progress entry added successfully')),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      await showApiError(context, ref, e);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Progress Entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

