import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:afya_fit/features/auth/providers/auth_provider.dart';
import 'package:afya_fit/features/auth/providers/user_provider.dart';
import 'package:afya_fit/features/auth/presentation/screens/login_screen.dart';
import 'package:afya_fit/core/routing/role_router.dart';

class AuthGuard extends ConsumerWidget {
  final Widget child;

  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (isAuthenticated) {
        if (isAuthenticated) {
          // Fetch user data to determine role
          final userAsync = ref.watch(currentUserProvider);
          
          return userAsync.when(
            data: (user) {
              if (user == null) {
                return child; // Fallback to default child
              }
              // Use role-based routing
              return RoleRouter.getHomeScreen(user.role);
            },
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => child, // Fallback to default child on error
          );
        } else {
          return const LoginScreen();
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(authProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
