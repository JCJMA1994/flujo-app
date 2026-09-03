import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/capture/presentation/pages/capture_onboarding_page.dart';
import '../../features/capture/presentation/pages/user_rules_page.dart';
import '../../features/onboarding/presentation/pages/initial_onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/transactions/presentation/pages/dashboard_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import 'adaptive_navigation_shell.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const dashboard = '/';
  static const transactions = '/transactions';
  static const userRules = '/rules';
  static const captureOnboarding = '/capture';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (_, __) => const SplashPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (_, __) => const LoginPage(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (_, __) => const RegisterPage(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (_, __) => const InitialOnboardingPage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AdaptiveNavigationShell(
        navigationShell: navigationShell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.dashboard,
              builder: (_, __) => const DashboardPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.transactions,
              builder: (_, __) => const TransactionsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.userRules,
              builder: (_, __) => const UserRulesPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.captureOnboarding,
              builder: (_, __) => const CaptureOnboardingPage(),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    body: Center(child: Text('Ruta no encontrada: ${state.uri}')),
  ),
);
