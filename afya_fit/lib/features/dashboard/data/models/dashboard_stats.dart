import 'package:json_annotation/json_annotation.dart';

part 'dashboard_stats.g.dart';

@JsonSerializable()
class DashboardStats {
  final int totalClients;
  final int totalWorkoutPlans;
  final int totalNutritionPlans;
  final int activeTasks;
  final int upcomingEvents;
  final int recentProgressEntries;

  const DashboardStats({
    required this.totalClients,
    required this.totalWorkoutPlans,
    required this.totalNutritionPlans,
    required this.activeTasks,
    required this.upcomingEvents,
    required this.recentProgressEntries,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardStatsToJson(this);
}
