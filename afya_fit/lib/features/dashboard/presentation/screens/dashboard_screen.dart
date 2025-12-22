import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/features/dashboard/providers/dashboard_provider.dart';
import 'package:afya_fit/features/auth/providers/auth_provider.dart';
import 'package:afya_fit/core/routing/app_router.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final recentClientsAsync = ref.watch(recentClientsProvider);
    final recentWorkoutsAsync = ref.watch(recentWorkoutsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(recentClientsProvider);
          ref.invalidate(recentWorkoutsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Text(
                'Welcome back!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "Here's an overview of your fitness business.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // Stats Grid
              statsAsync.when(
                data: (stats) => _StatsGrid(stats: stats),
                loading: () => const _StatsGridLoading(),
                error: (error, stack) => _StatsGridError(error: error),
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              const _QuickActions(),

              const SizedBox(height: 24),

              // Recent Activity
              Text(
                'Recent Activity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: recentClientsAsync.when(
                      data: (clients) => _RecentClientsCard(clients: clients),
                      loading: () => const _RecentClientsCardLoading(),
                      error: (error, stack) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: recentWorkoutsAsync.when(
                      data: (workouts) =>
                          _RecentWorkoutsCard(workouts: workouts),
                      loading: () => const _RecentWorkoutsCardLoading(),
                      error: (error, stack) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final dynamic stats;

  const _StatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _StatCard(
          title: 'Active Clients',
          value: stats.totalClients.toString(),
          icon: Icons.people,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'Workout Plans',
          value: stats.totalWorkoutPlans.toString(),
          icon: Icons.fitness_center,
          color: Colors.green,
        ),
        _StatCard(
          title: 'Nutrition Plans',
          value: stats.totalNutritionPlans.toString(),
          icon: Icons.restaurant,
          color: Colors.purple,
        ),
        _StatCard(
          title: 'Active Tasks',
          value: stats.activeTasks.toString(),
          icon: Icons.task,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Upcoming Events',
          value: stats.upcomingEvents.toString(),
          icon: Icons.calendar_today,
          color: Colors.indigo,
        ),
      ],
    );
  }
}

class _StatsGridLoading extends StatelessWidget {
  const _StatsGridLoading();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: List.generate(
        5,
        (index) => const Card(
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _StatsGridError extends StatelessWidget {
  final Object error;

  const _StatsGridError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              'Failed to load stats',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          label: 'View Workouts',
          icon: Icons.fitness_center,
          color: Colors.green,
          onTap: () {
            Navigator.pushNamed(context, AppRouter.workouts);
          },
        ),
        _ActionButton(
          label: 'View Nutrition',
          icon: Icons.restaurant,
          color: Colors.purple,
          onTap: () {
            Navigator.pushNamed(context, AppRouter.nutrition);
          },
        ),
        _ActionButton(
          label: 'View Tasks',
          icon: Icons.task_alt,
          color: Colors.orange,
          onTap: () {
            Navigator.pushNamed(context, AppRouter.tasks);
          },
        ),
        _ActionButton(
          label: 'Add Client',
          icon: Icons.person_add,
          color: Colors.blue,
          onTap: () {
            // TODO: Navigate to add client
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add client feature coming soon')),
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentClientsCard extends StatelessWidget {
  final List<Map<String, dynamic>> clients;

  const _RecentClientsCard({required this.clients});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Clients',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (clients.isEmpty)
              Text(
                'No clients yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...clients.map((client) => _ClientItem(client: client)),
          ],
        ),
      ),
    );
  }
}

class _RecentClientsCardLoading extends StatelessWidget {
  const _RecentClientsCardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ClientItem extends StatelessWidget {
  final Map<String, dynamic> client;

  const _ClientItem({required this.client});

  @override
  Widget build(BuildContext context) {
    final firstName = client['first_name'] as String? ?? '';
    final lastName = client['last_name'] as String? ?? '';
    final email = client['email'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$firstName $lastName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Navigate to client details
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

class _RecentWorkoutsCard extends StatelessWidget {
  final List<Map<String, dynamic>> workouts;

  const _RecentWorkoutsCard({required this.workouts});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Workouts',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (workouts.isEmpty)
              Text(
                'No workout plans yet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              ...workouts.map((workout) => _WorkoutItem(workout: workout)),
          ],
        ),
      ),
    );
  }
}

class _RecentWorkoutsCardLoading extends StatelessWidget {
  const _RecentWorkoutsCardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _WorkoutItem extends StatelessWidget {
  final Map<String, dynamic> workout;

  const _WorkoutItem({required this.workout});

  @override
  Widget build(BuildContext context) {
    final name = workout['name'] as String? ?? 'Unnamed';
    final durationWeeks = workout['duration_weeks'] as int? ?? 0;
    final difficulty = workout['difficulty'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  '$durationWeeks weeks • $difficulty',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // TODO: Navigate to workout details
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}
