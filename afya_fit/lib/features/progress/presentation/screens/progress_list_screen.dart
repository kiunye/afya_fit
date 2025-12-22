import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/features/progress/providers/progress_provider.dart';
import 'package:intl/intl.dart';

class ProgressListScreen extends HookConsumerWidget {
  final String clientId;

  const ProgressListScreen({
    super.key,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(progressEntriesProvider(clientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracking'),
      ),
      body: progressAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.trending_up,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No progress entries yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start tracking your client\'s progress',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(progressEntriesProvider(clientId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _ProgressCard(entry: entry);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading progress: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(progressEntriesProvider(clientId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add progress entry feature coming soon'),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final Map<String, dynamic> entry;

  const _ProgressCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr = entry['date'] as String?;
    final weight = entry['weight'] as num?;
    final bodyFat = entry['body_fat_percentage'] as num?;
    final notes = entry['notes'] as String?;

    DateTime? date;
    if (dateStr != null) {
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        // Invalid date format
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (date != null)
              Text(
                DateFormat('MMM dd, yyyy').format(date),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              )
            else
              Text(
                'Progress Entry',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (weight != null) ...[
                  Expanded(
                    child: _MetricItem(
                      label: 'Weight',
                      value: '${weight.toStringAsFixed(1)} kg',
                      icon: Icons.monitor_weight,
                    ),
                  ),
                ],
                if (bodyFat != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricItem(
                      label: 'Body Fat',
                      value: '${bodyFat.toStringAsFixed(1)}%',
                      icon: Icons.percent,
                    ),
                  ),
                ],
              ],
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                notes,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
