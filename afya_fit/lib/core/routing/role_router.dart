import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/core/access/access.dart';
import 'package:afya_fit/features/auth/providers/auth_provider.dart';
import 'package:afya_fit/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:afya_fit/features/admin/presentation/screens/admin_trainers_screen.dart';
import 'package:afya_fit/features/admin/presentation/screens/admin_clients_screen.dart';

enum HomeKind { coach, client, platform }

/// Picks the home screen from what the user can do, not from a role name, so a
/// new kind of coach (such as an organization owner) needs no change here.
class RoleRouter {
  static HomeKind homeKindFor(Access access) {
    if (access.isPlatformAdmin) return HomeKind.platform;
    if (access.isClient) return HomeKind.client;
    return HomeKind.coach;
  }

  static Widget getHomeScreen(Access access) {
    switch (homeKindFor(access)) {
      case HomeKind.platform:
        return const AdminDashboardScreen();
      case HomeKind.client:
        return const CustomerDashboardScreen();
      case HomeKind.coach:
        return const DashboardScreen();
    }
  }
}

// Customer Dashboard Screen
class CustomerDashboardScreen extends HookConsumerWidget {
  const CustomerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
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
          // Refresh customer data
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
                "Here's your fitness journey overview.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionButton(
                    label: 'My Workouts',
                    icon: Icons.fitness_center,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/workouts');
                    },
                  ),
                  _ActionButton(
                    label: 'My Nutrition',
                    icon: Icons.restaurant,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pushNamed(context, '/nutrition');
                    },
                  ),
                  _ActionButton(
                    label: 'My Progress',
                    icon: Icons.trending_up,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/progress');
                    },
                  ),
                  _ActionButton(
                    label: 'Subscription',
                    icon: Icons.credit_card,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
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

// Admin Dashboard Screen
class AdminDashboardScreen extends HookConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
          // Refresh admin data
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Text(
                'Admin Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Manage your organization: trainers and clients.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionButton(
                    label: 'View Trainers',
                    icon: Icons.people,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminTrainersScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    label: 'View Clients',
                    icon: Icons.group,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminClientsScreen(),
                        ),
                      );
                    },
                  ),
                  _ActionButton(
                    label: 'Subscription',
                    icon: Icons.credit_card,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pushNamed(context, '/subscription');
                    },
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
