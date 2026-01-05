import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class ReminderSettingsScreen extends HookConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Settings'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchSubscription(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final subscription = snapshot.data;
          final reminders = subscription?['reminder_preferences'] as Map<String, dynamic>? ?? {};
          final enabled = reminders['enabled'] as bool? ?? true;
          final daysBefore = reminders['days_before_expiry'] as List<dynamic>? ?? [7, 3, 1];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable Reminders'),
                    subtitle: const Text('Receive email reminders before subscription expires'),
                    value: enabled,
                    onChanged: (value) async {
                      await _updateReminders(ref, {'enabled': value, 'days_before_expiry': daysBefore});
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const ReminderSettingsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (enabled) ...[
                  Text(
                    'Remind me (days before expiry)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...([1, 3, 7, 14, 30].map((day) {
                    final isSelected = daysBefore.contains(day);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        title: Text('$day ${day == 1 ? 'day' : 'days'} before'),
                        value: isSelected,
                        onChanged: (value) async {
                          final newDays = List<int>.from(daysBefore);
                          if (value == true) {
                            if (!newDays.contains(day)) {
                              newDays.add(day);
                              newDays.sort();
                            }
                          } else {
                            newDays.remove(day);
                          }
                          await _updateReminders(ref, {'enabled': enabled, 'days_before_expiry': newDays});
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const ReminderSettingsScreen(),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  })),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchSubscription(WidgetRef ref) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(ApiConstants.meSubscription);
      return response['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }

  Future<void> _updateReminders(WidgetRef ref, Map<String, dynamic> reminders) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(ApiConstants.meSubscriptionReminders, body: {
        'reminder_preferences': reminders,
      });
    } catch (e) {
      // Handle error
    }
  }
}

