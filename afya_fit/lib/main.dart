import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afya_fit/core/access/access_banner.dart';
import 'package:afya_fit/core/utils/app_theme.dart';
import 'package:afya_fit/core/routing/app_router.dart';
import 'package:afya_fit/features/auth/presentation/widgets/auth_guard.dart';
import 'package:afya_fit/features/dashboard/presentation/screens/dashboard_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: AfyaFitApp(),
    ),
  );
}

class AfyaFitApp extends StatelessWidget {
  const AfyaFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Afya Fit',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthGuard(
        child: DashboardScreen(), // Fallback, will be replaced by role-based routing
      ),
      builder: (context, child) =>
          AccessShell(child: child ?? const SizedBox.shrink()),
      onGenerateRoute: AppRouter.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
