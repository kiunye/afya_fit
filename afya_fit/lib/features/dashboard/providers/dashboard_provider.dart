import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:afya_fit/core/providers/api_provider.dart';
import 'package:afya_fit/features/dashboard/data/repositories/dashboard_repository.dart';
import 'package:afya_fit/features/dashboard/data/models/dashboard_stats.dart';

part 'dashboard_provider.g.dart';

@riverpod
DashboardRepository dashboardRepository(Ref ref) {
  return DashboardRepository(ref.read(apiClientProvider));
}

@riverpod
Future<DashboardStats> dashboardStats(Ref ref) async {
  final repository = ref.read(dashboardRepositoryProvider);
  return repository.getStats();
}

@riverpod
Future<List<Map<String, dynamic>>> recentClients(Ref ref) async {
  final repository = ref.read(dashboardRepositoryProvider);
  return repository.getRecentClients();
}

@riverpod
Future<List<Map<String, dynamic>>> recentWorkouts(Ref ref) async {
  final repository = ref.read(dashboardRepositoryProvider);
  return repository.getRecentWorkouts();
}
