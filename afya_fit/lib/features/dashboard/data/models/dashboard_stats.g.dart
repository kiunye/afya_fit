// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardStats _$DashboardStatsFromJson(Map<String, dynamic> json) =>
    DashboardStats(
      totalClients: (json['totalClients'] as num).toInt(),
      totalWorkoutPlans: (json['totalWorkoutPlans'] as num).toInt(),
      totalNutritionPlans: (json['totalNutritionPlans'] as num).toInt(),
      activeTasks: (json['activeTasks'] as num).toInt(),
      upcomingEvents: (json['upcomingEvents'] as num).toInt(),
      recentProgressEntries: (json['recentProgressEntries'] as num).toInt(),
    );

Map<String, dynamic> _$DashboardStatsToJson(DashboardStats instance) =>
    <String, dynamic>{
      'totalClients': instance.totalClients,
      'totalWorkoutPlans': instance.totalWorkoutPlans,
      'totalNutritionPlans': instance.totalNutritionPlans,
      'activeTasks': instance.activeTasks,
      'upcomingEvents': instance.upcomingEvents,
      'recentProgressEntries': instance.recentProgressEntries,
    };
