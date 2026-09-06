import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/capture/presentation/pages/capture_onboarding_page.dart';
import '../../features/capture/presentation/pages/user_rules_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/onboarding/presentation/pages/initial_onboarding_page.dart';
import '../../features/onboarding/presentation/pages/splash_page.dart';
import '../../features/transactions/presentation/pages/dashboard_page.dart';
import '../../features/transactions/presentation/pages/transactions_page.dart';
import '../di/injection.dart';
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
  static const chat = '/chat';
  static const profile = '/profile';
}

/// Escucha un [Stream] y notifica a los listeners de [ChangeNotifier],
/// permitiendo que [GoRouter] reaccione reactivamente a cambios en el estado de autenticación.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  refreshListenable: GoRouterRefreshStream(getIt<AuthCubit>().stream),
  redirect: (context, state) {
    final authCubit = getIt<AuthCubit>();
    final isAuthenticated = authCubit.state.isAuthenticated;
    final location = state.matchedLocation;

    final isSplash = location == AppRoutes.splash;
    final isOnboarding = location == AppRoutes.onboarding;
    final isAuthRoute =
        location == AppRoutes.login || location == AppRoutes.register;

    // Permitir splash y onboarding sin interferir
    if (isSplash || isOnboarding) {
      return null;
    }

    // Si no está autenticado e intenta acceder a una ruta protegida
    if (!isAuthenticated) {
      return isAuthRoute ? null : AppRoutes.login;
    }

    // Si ya está autenticado e intenta ir a login o registro, redirigir a dashboard
    if (isAuthRoute) {
      return AppRoutes.dashboard;
    }

    return null;
  },
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
    GoRoute(
      path: AppRoutes.chat,
      builder: (_, __) => const ChatPage(),
    ),
    GoRoute(
      path: AppRoutes.userRules,
      builder: (_, __) => const UserRulesPage(),
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
              path: AppRoutes.captureOnboarding,
              builder: (_, __) => const CaptureOnboardingPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfilePage(),
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
