import 'dart:io';

class ApiConstants {
  // Base URL - automatically detects platform
  // Android emulator: use 10.0.2.2 to access host machine's localhost
  // iOS simulator: localhost works fine
  // Physical devices: use your machine's IP address (e.g., http://192.168.1.100:4000)
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android emulator special IP to access host machine
      return 'http://10.0.2.2:4000';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return 'http://localhost:4000';
    } else {
      // Desktop or other platforms
      return 'http://localhost:4000';
    }
  }
  
  static String get apiBaseUrl => '$baseUrl/api/v1';

  // API Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';

  // Client endpoints
  static String clients() => '/clients';
  static String client(String id) => '/clients/$id';
  static String clientInvite(String id) => '/clients/$id/invite';
  static String clientProgress(String id) => '/clients/$id/progress';

  // Workout endpoints
  static String workoutPlans() => '/workout-plans';
  static String workoutPlan(String id) => '/workout-plans/$id';
  static String workoutPlanTemplates() => '/workout-plans/templates';
  static String workoutPlanDuplicate(String id) => '/workout-plans/$id/duplicate';
  static String clientWorkouts(String clientId) => '/clients/$clientId/workouts';
  static String clientWorkout(String id) => '/client-workouts/$id';
  static String clientWorkoutComplete(String id) => '/client-workouts/$id/complete';

  // Nutrition endpoints
  static String nutritionPlans() => '/nutrition-plans';
  static String nutritionPlan(String id) => '/nutrition-plans/$id';
  static String clientNutrition(String clientId) => '/clients/$clientId/nutrition';

  // Progress endpoints
  static String progress(String id) => '/progress/$id';
  static String progressAnalytics(String clientId) => '/clients/$clientId/progress/analytics';

  // Task endpoints
  static String tasks() => '/tasks';
  static String task(String id) => '/tasks/$id';
  static String tasksBulk() => '/tasks/bulk';
  static String taskComplete(String id) => '/tasks/$id/complete';
  static String clientTasks(String clientId) => '/clients/$clientId/tasks';

  // Calendar endpoints
  static String calendarEvents() => '/calendar/events';
  static String calendarEvent(String id) => '/calendar/events/$id';
  static String calendarUpcoming() => '/calendar/upcoming';

  // Subscription endpoints
  static String subscriptions() => '/subscriptions';
  static String subscriptionInvoices() => '/subscriptions/invoices';
  static String paymentInitialize() => '/payments/initialize';

  // Client-friendly /me/* endpoints
  static const String meWorkouts = '/me/workouts';
  static const String meNutrition = '/me/nutrition';
  static const String meProgress = '/me/progress';
  static const String meSubscription = '/me/subscription';
  static const String meSubscriptionReminders = '/me/subscription/reminders';
  static const String meTasks = '/me/tasks';
}
