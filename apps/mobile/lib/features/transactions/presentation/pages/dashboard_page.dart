import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../capture/presentation/cubit/capture_cubit.dart';
import '../../../insights/presentation/cubit/insights_cubit.dart';
import '../../../insights/presentation/widgets/insights_card.dart';
import '../../domain/entities/transaction.dart';
import '../bloc/transaction_bloc.dart';
import '../cubit/dashboard_cubit.dart';
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
      ],
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
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
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Mes anterior',
            onPressed: cubit.previousMonth,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Mes siguiente',
            onPressed: cubit.nextMonth,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Ver movimientos',
            onPressed: () => context.go(AppRoutes.transactions),
          ),
          BlocBuilder<CaptureCubit, CaptureState>(
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
              const Center(child: CircularProgressIndicator()),
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
                      // Columna Izquierda: Balance y Resumen
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MonthHeader(summary: summary),
                            const SizedBox(height: 16),
                            _BalanceHeroCard(summary: summary),
                            if (summary.variation != null) ...[
                              const SizedBox(height: 14),
                              _VariationBanner(variation: summary.variation!),
                            ],
                            const SizedBox(height: 14),
                            const InsightsCard(),
                            const SizedBox(height: 20),
                            const _QuickActionsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Columna Derecha: Desglose por Categoría
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CategorySectionHeader(
                              count: summary.byCategory.length,
                            ),
                            const SizedBox(height: 12),
                            _CategoryBreakdownList(items: summary.byCategory),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Móvil: Flujo vertical
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _MonthHeader(summary: summary),
                  const SizedBox(height: 14),
                  _BalanceHeroCard(summary: summary),
                  if (summary.variation != null) ...[
                    const SizedBox(height: 14),
                    _VariationBanner(variation: summary.variation!),
                  ],
                  const SizedBox(height: 14),
                  const InsightsCard(),
                  const SizedBox(height: 24),
                  _CategorySectionHeader(count: summary.byCategory.length),
                  const SizedBox(height: 10),
                  _CategoryBreakdownList(items: summary.byCategory),
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

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = DateFormat('MMMM yyyy', 'es').format(summary.month);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          monthName[0].toUpperCase() + monthName.substring(1),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${summary.month.year}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceHeroCard extends StatelessWidget {
  const _BalanceHeroCard({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final isNetPositive = summary.netBalance >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNetPositive
              ? [const Color(0xFF0F766E), const Color(0xFF0D9488)]
              : [const Color(0xFF991B1B), const Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isNetPositive
                    ? const Color(0xFF0D9488)
                    : const Color(0xFFDC2626))
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BALANCE NETO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Colors.white70,
                ),
              ),
              Icon(
                isNetPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${isNetPositive ? '+' : '-'}S/ ${summary.netBalance.abs().toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ingresos',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            'S/ ${summary.incomeTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gastos',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            'S/ ${summary.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.speed_rounded,
                          size: 14,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Promedio/d',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'S/ ${summary.dailyAverage.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VariationBanner extends StatelessWidget {
  const _VariationBanner({required this.variation});

  final double variation;

  @override
  Widget build(BuildContext context) {
    final isSaving = variation < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSaving
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSaving
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSaving ? Icons.savings_outlined : Icons.info_outline_rounded,
            size: 18,
            color: isSaving ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSaving
                  ? 'Excelente: Gastaste ${(variation.abs() * 100).round()}% menos que el mes anterior.'
                  : 'Atención: Llevas ${(variation * 100).round()}% más que el mes anterior.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSaving ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accesos rápidos',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE0F2FE),
                child:
                    Icon(Icons.add_rounded, size: 18, color: Color(0xFF0284C7)),
              ),
              title: const Text('Registrar movimiento'),
              subtitle: const Text('Gasto o ingreso manual'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => TransactionFormSheet.show(context),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
              ),
              title: const Text('Captura automática'),
              subtitle: const Text('Yape, Plin y bancos'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => context.go(AppRoutes.captureOnboarding),
            ),
            const Divider(height: 1),
            ListTile(
              dense: true,
              leading: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFF3E8FF),
                child: Icon(
                  Icons.auto_fix_high_rounded,
                  size: 18,
                  color: Color(0xFF9333EA),
                ),
              ),
              title: const Text('Reglas inteligentes'),
              subtitle: const Text('Categorización automática'),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => context.go(AppRoutes.userRules),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySectionHeader extends StatelessWidget {
  const _CategorySectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Gastos por categoría',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$count categorías',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CategoryBreakdownList extends StatelessWidget {
  const _CategoryBreakdownList({required this.items});

  final List<CategoryTotal> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Column(
              children: [
                const Text('💸', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 8),
                Text(
                  'Sin gastos registrados este mes',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final item in items)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          item.category.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${(item.share * 100).toStringAsFixed(1)}% del total',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'S/ ${item.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: item.share,
                      minHeight: 6,
                      backgroundColor: theme.colorScheme.surface,
                      valueColor: AlwaysStoppedAnimation(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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
