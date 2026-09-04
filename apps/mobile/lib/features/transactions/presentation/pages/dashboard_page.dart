import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../capture/presentation/cubit/capture_cubit.dart';
import '../../../insights/presentation/cubit/insights_cubit.dart';
import '../../../insights/presentation/widgets/insights_card.dart';
import '../../domain/entities/transaction.dart';
import '../bloc/transaction_bloc.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/privacy_cubit.dart';
import '../widgets/dashboard/balance_hero_card.dart';
import '../widgets/dashboard/category_breakdown_list.dart';
import '../widgets/dashboard/daily_budget_card.dart';
import '../widgets/dashboard/dashboard_shimmer.dart';
import '../widgets/dashboard/month_selector_header.dart';
import '../widgets/dashboard/quick_actions_card.dart';
import '../widgets/dashboard/variation_banner.dart';
import '../widgets/transaction_form_sheet.dart';
import '../widgets/user_profile_sheet.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<DashboardCubit>()..start()),
        BlocProvider(
          create: (_) => getIt<TransactionBloc>()
            ..add(const TransactionsSubscriptionRequested()),
        ),
        BlocProvider(create: (_) => getIt<InsightsCubit>()..start()),
        BlocProvider.value(value: getIt<PrivacyCubit>()),
      ],
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flujo',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Gastos & Yape',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          BlocBuilder<PrivacyCubit, PrivacyState>(
            builder: (context, privacy) {
              return IconButton(
                icon: Icon(
                  privacy.isObscured
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                tooltip:
                    privacy.isObscured ? 'Mostrar saldos' : 'Ocultar saldos',
                onPressed: () => context.read<PrivacyCubit>().toggle(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Ver movimientos',
            onPressed: () => context.go(AppRoutes.transactions),
          ),
          BlocBuilder<CaptureCubit, CaptureState>(
            buildWhen: (prev, curr) => prev.permission != curr.permission,
            builder: (context, state) {
              final isGranted = state.permission == CapturePermission.granted;
              return IconButton(
                icon: Badge(
                  isLabelVisible: isGranted,
                  backgroundColor: Colors.green,
                  smallSize: 8,
                  child: Icon(
                    isGranted
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color: isGranted ? theme.colorScheme.primary : null,
                  ),
                ),
                tooltip: isGranted
                    ? 'Captura automática activa'
                    : 'Activar captura automática',
                onPressed: () => context.go(AppRoutes.captureOnboarding),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Asistente Flujo',
            onPressed: () => context.push(AppRoutes.chat),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Perfil y sincronización',
            onPressed: () => UserProfileSheet.show(context),
          ),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listenWhen: (prev, curr) =>
            prev.failure != curr.failure ||
            prev.summary?.month != curr.summary?.month,
        listener: (context, state) {
          final summary = state.summary;
          if (summary != null) {
            context.read<InsightsCubit>().updateMonth(summary.month);
          }
          final failure = state.failure;
          if (failure == null) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failure.message)));
        },
        buildWhen: (prev, curr) =>
            prev.status != curr.status || prev.summary != curr.summary,
        builder: (context, state) {
          return switch (state.status) {
            DashboardStatus.initial ||
            DashboardStatus.loading =>
              const DashboardShimmer(),
            DashboardStatus.failure => _RetryView(
                onRetry: () => context.read<DashboardCubit>().start(),
              ),
            DashboardStatus.success => _SummaryView(summary: state.summary!),
          };
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TransactionFormSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Registrar'),
        tooltip: 'Registrar movimiento manual',
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<DashboardCubit>().start(month: summary.month);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 750;

          if (isWide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MonthSelectorHeader(summary: summary),
                            const SizedBox(height: 16),
                            BalanceHeroCard(summary: summary),
                            if (summary.variation != null) ...[
                              const SizedBox(height: 14),
                              VariationBanner(
                                variation: summary.variation!,
                                absoluteDifference: summary.absoluteVariation,
                              ),
                            ],
                            const SizedBox(height: 14),
                            DailyBudgetCard(summary: summary),
                            const SizedBox(height: 14),
                            const InsightsCard(),
                            const SizedBox(height: 20),
                            const QuickActionsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CategorySectionHeader(
                              count: summary.byCategory.length,
                            ),
                            const SizedBox(height: 12),
                            CategoryBreakdownList(items: summary.byCategory),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  MonthSelectorHeader(summary: summary),
                  const SizedBox(height: 14),
                  BalanceHeroCard(summary: summary),
                  if (summary.variation != null) ...[
                    const SizedBox(height: 14),
                    VariationBanner(
                      variation: summary.variation!,
                      absoluteDifference: summary.absoluteVariation,
                    ),
                  ],
                  const SizedBox(height: 14),
                  DailyBudgetCard(summary: summary),
                  const SizedBox(height: 14),
                  const InsightsCard(),
                  const SizedBox(height: 24),
                  CategorySectionHeader(count: summary.byCategory.length),
                  const SizedBox(height: 10),
                  CategoryBreakdownList(items: summary.byCategory),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RetryView extends StatelessWidget {
  const _RetryView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No pudimos cargar tu resumen',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifica que la base de datos esté lista y vuelve a intentar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
