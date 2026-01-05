import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/features/progress/providers/progress_provider.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/core/constants/api_constants.dart';

class ProgressAnalyticsScreen extends HookConsumerWidget {
  final String clientId;

  const ProgressAnalyticsScreen({
    super.key,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchAnalytics(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Progress Analytics')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Progress Analytics')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading analytics: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ProgressAnalyticsScreen(clientId: clientId),
                        ),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final analytics = snapshot.data ?? {};

        return Scaffold(
          appBar: AppBar(
            title: const Text('Progress Analytics'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ProgressAnalyticsScreen(clientId: clientId),
                ),
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  if (analytics['weight_stats'] != null) ...[
                    _StatCard(
                      title: 'Weight Statistics',
                      stats: analytics['weight_stats'] as Map<String, dynamic>? ?? {},
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (analytics['body_fat_stats'] != null) ...[
                    _StatCard(
                      title: 'Body Fat Statistics',
                      stats: analytics['body_fat_stats'] as Map<String, dynamic>? ?? {},
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Placeholder for charts
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress Charts',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text('Charts coming soon'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchAnalytics(WidgetRef ref) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiConstants.progressAnalytics(clientId),
      );
      return response['data'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> stats;

  const _StatCard({
    required this.title,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (stats['average'] != null)
              _StatRow(label: 'Average', value: stats['average'].toString()),
            if (stats['min'] != null)
              _StatRow(label: 'Minimum', value: stats['min'].toString()),
            if (stats['max'] != null)
              _StatRow(label: 'Maximum', value: stats['max'].toString()),
            if (stats['trend'] != null)
              _StatRow(
                label: 'Trend',
                value: stats['trend'].toString(),
                isTrend: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTrend;

  const _StatRow({
    required this.label,
    required this.value,
    this.isTrend = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isTrend
                      ? (value.toLowerCase().contains('up')
                          ? Colors.green
                          : value.toLowerCase().contains('down')
                              ? Colors.red
                              : null)
                      : null,
                ),
          ),
        ],
      ),
    );
  }
}

