import 'package:flutter/material.dart';
import 'package:afya_fit/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:afya_fit/features/clients/presentation/screens/client_list_screen.dart';
import 'package:afya_fit/features/workouts/presentation/screens/workout_list_screen.dart';
import 'package:afya_fit/features/nutrition/presentation/screens/nutrition_list_screen.dart';
import 'package:afya_fit/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:afya_fit/features/progress/presentation/screens/progress_list_screen.dart';
import 'package:afya_fit/features/subscription/presentation/screens/subscription_screen.dart';

class AppRouter {
  static const String dashboard = '/';
  static const String clients = '/clients';
  static const String workouts = '/workouts';
  static const String nutrition = '/nutrition';
  static const String tasks = '/tasks';
  static const String progress = '/progress';
  static const String subscription = '/subscription';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        );
      case clients:
        return MaterialPageRoute(
          builder: (_) => const ClientListScreen(),
        );
      case workouts:
        return MaterialPageRoute(
          builder: (_) => const WorkoutListScreen(),
        );
      case nutrition:
        return MaterialPageRoute(
          builder: (_) => const NutritionListScreen(),
        );
      case tasks:
        return MaterialPageRoute(
          builder: (_) => const TaskListScreen(),
        );
      case progress:
        final args = settings.arguments;
        // If no clientId provided, use empty string (for customers viewing their own progress)
        final clientId = args is String ? args : '';
        return MaterialPageRoute(
          builder: (_) => ProgressListScreen(clientId: clientId),
        );
      case subscription:
        return MaterialPageRoute(
          builder: (_) => const SubscriptionScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        );
    }
  }
}
