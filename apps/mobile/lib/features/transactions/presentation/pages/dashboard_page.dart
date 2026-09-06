import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../insights/presentation/cubit/insights_cubit.dart';
import '../../domain/entities/transaction.dart';
import '../bloc/transaction_bloc.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/privacy_cubit.dart';
import '../widgets/dashboard/balance_hero_card.dart';
import '../widgets/dashboard/category_breakdown_list.dart';
import '../widgets/dashboard/dashboard_shimmer.dart';
import '../widgets/dashboard/month_selector_header.dart';
import '../widgets/dashboard/pending_review_banner.dart';
import '../widgets/dashboard/recent_transactions_card.dart';

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
        title: Text(
          'Flujo',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          BlocBuilder<PrivacyCubit, PrivacyState>(
            builder: (context, privacy) {
              return IconButton(
                icon: Icon(
                  privacy.isObscured ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 20,
                ),
                tooltip:
                    privacy.isObscured ? 'Mostrar saldos' : 'Ocultar saldos',
                onPressed: () => context.read<PrivacyCubit>().toggle(),
              );
            },
          ),
          BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final name = authState.user?.name ?? 'Usuario';
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
              return Padding(
                padding: const EdgeInsets.only(right: 16, left: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.go(AppRoutes.profile),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: FlujoTokens.verdePetroleo,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            },
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
                            const SizedBox(height: 16),
                            BlocBuilder<TransactionBloc, TransactionState>(
                              builder: (context, txState) {
                                final pending = txState.transactions
                                    .where((t) => !t.reviewed)
                                    .toList();
                                if (pending.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return PendingReviewBanner(
                                  pendingTransactions: pending,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: BlocBuilder<TransactionBloc, TransactionState>(
                          builder: (context, txState) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RecentTransactionsCard(
                                  transactions: txState.transactions,
                                ),
                                if (summary.byCategory.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  CategorySectionHeader(
                                    count: summary.byCategory.length,
                                  ),
                                  const SizedBox(height: 12),
                                  CategoryBreakdownList(
                                    items: summary.byCategory,
                                  ),
                                ],
                              ],
                            );
                          },
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  MonthSelectorHeader(summary: summary),
                  const SizedBox(height: 12),
                  BalanceHeroCard(summary: summary),
                  const SizedBox(height: 16),
                  BlocBuilder<TransactionBloc, TransactionState>(
                    builder: (context, txState) {
                      final transactions = txState.transactions;
                      final pending =
                          transactions.where((t) => !t.reviewed).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (pending.isNotEmpty) ...[
                            PendingReviewBanner(
                              pendingTransactions: pending,
                            ),
                            const SizedBox(height: 16),
                          ],
                          RecentTransactionsCard(
                            transactions: transactions,
                          ),
                        ],
                      );
                    },
                  ),
                  if (summary.byCategory.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    CategorySectionHeader(count: summary.byCategory.length),
                    const SizedBox(height: 10),
                    CategoryBreakdownList(items: summary.byCategory),
                  ],
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
