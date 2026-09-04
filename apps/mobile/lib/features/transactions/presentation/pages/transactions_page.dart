import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../capture/presentation/cubit/capture_cubit.dart';
import '../../data/services/transaction_export_service.dart';
import '../../domain/entities/transaction.dart';
import '../bloc/transaction_bloc.dart';
import '../cubit/privacy_cubit.dart';
import '../widgets/review_transaction_sheet.dart';
import '../widgets/transaction_form_sheet.dart';
import '../widgets/transactions_shimmer.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => getIt<TransactionBloc>()
            ..add(const TransactionsSubscriptionRequested()),
        ),
        BlocProvider.value(value: getIt<PrivacyCubit>()),
      ],
      child: const _TransactionsView(),
    );
  }
}

class _TransactionsView extends StatelessWidget {
  const _TransactionsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _SearchField(),
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
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar a CSV',
            onPressed: () => _exportTransactions(context),
          ),
          IconButton(
            icon: const Icon(Icons.rule_folder_outlined),
            tooltip: 'Reglas automáticas',
            onPressed: () => context.push(AppRoutes.userRules),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: _FilterBar(),
        ),
      ),
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listenWhen: (p, c) => p.failure != c.failure && c.failure != null,
        listener: (context, state) {
          if (state.failure != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.failure!.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
          }
        },
        buildWhen: (p, c) =>
            p.status != c.status ||
            p.transactions != c.transactions ||
            p.isSyncing != c.isSyncing,
        builder: (context, state) {
          if (state.status == TransactionStatus.loading) {
            return const TransactionsShimmer();
          }
          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<TransactionBloc>()
                  .add(const TransactionSyncRequested());
            },
            child: state.transactions.isEmpty
                ? const _EmptyView()
                : _buildTransactionsList(context, state),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context, TransactionState state) {
    final isObscured =
        context.watch<PrivacyCubit?>()?.state.isObscured ?? false;
    final expenses = state.transactions.where((t) => t.isExpense).toList();
    final totalExpense = expenses.fold<double>(0, (sum, t) => sum + t.amount);
    final avgExpense = expenses.isEmpty ? 0.0 : totalExpense / expenses.length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${state.transactions.length} movimientos',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isObscured
                        ? 'Promedio: S/ ••••'
                        : 'Promedio: S/ ${avgExpense.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 680;
              if (isWide) {
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 480,
                    mainAxisExtent: 82,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: state.transactions.length,
                  itemBuilder: (_, i) => _TransactionCard(
                    transaction: state.transactions[i],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: state.transactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _TransactionCard(
                  transaction: state.transactions[i],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _exportTransactions(BuildContext context) async {
    final state = context.read<TransactionBloc>().state;
    if (state.transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay transacciones para exportar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final exportService = getIt<TransactionExportService>();
      await exportService.shareCsv(transactions: state.transactions);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        decoration: const InputDecoration(
          hintText: 'Buscar comercio, remitente...',
          prefixIcon: Icon(Icons.search_rounded, size: 20),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (value) =>
            context.read<TransactionBloc>().add(SearchQueryChanged(value)),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      buildWhen: (p, c) =>
          p.filter.scope != c.filter.scope ||
          p.filter.type != c.filter.type ||
          p.filter.parser != c.filter.parser,
      builder: (context, state) {
        final bloc = context.read<TransactionBloc>();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Tipo chips
              for (final entry in <(String, TransactionType?)>[
                ('Todos', null),
                ('Gastos', TransactionType.expense),
                ('Ingresos', TransactionType.income),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(entry.$1),
                    selected: state.filter.type == entry.$2,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      bloc.add(TypeFilterChanged(entry.$2));
                    },
                  ),
                ),
              const SizedBox(width: 4),
              Container(
                height: 24,
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(width: 8),
              // Ámbito chips
              for (final entry in <(String, TransactionScope?)>[
                ('Personal', TransactionScope.personal),
                ('Negocio', TransactionScope.business),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(entry.$1),
                    selected: state.filter.scope == entry.$2,
                    onSelected: (selected) {
                      HapticFeedback.selectionClick();
                      bloc.add(ScopeFilterChanged(selected ? entry.$2 : null));
                    },
                  ),
                ),
              const SizedBox(width: 4),
              Container(
                height: 24,
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(width: 8),
              // Entidad / Parser chips
              for (final entry in <(String, String?)>[
                ('Yape', 'yape'),
                ('Plin', 'plin'),
                ('BCP', 'bcp'),
                ('BBVA', 'bbva'),
                ('Interbank', 'interbank'),
                ('Scotiabank', 'scotiabank'),
                ('PayPal', 'paypal'),
                ('Manual', 'manual'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(entry.$1),
                    selected: state.filter.parser == entry.$2,
                    onSelected: (selected) {
                      HapticFeedback.selectionClick();
                      bloc.add(ParserFilterChanged(selected ? entry.$2 : null));
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.isIncome;
    final isObscured =
        context.watch<PrivacyCubit?>()?.state.isObscured ?? false;
    final money = NumberFormat.currency(
      locale: 'es_PE',
      symbol: transaction.currency == 'PEN' ? 'S/ ' : r'$ ',
    );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ReviewTransactionSheet.show(context, transaction),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: isIncome
                      ? Colors.green.withValues(alpha: 0.12)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  transaction.category.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.merchant,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          DateFormat('d MMM, HH:mm', 'es')
                              .format(transaction.occurredAt),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (transaction.parser != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              transaction.parser!.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (transaction.scope == TransactionScope.business)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Negocio',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isObscured
                        ? '${isIncome ? '+' : '-'}••••'
                        : '${isIncome ? '+' : '-'}${money.format(transaction.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isIncome ? Colors.green : null,
                    ),
                  ),
                  if (transaction.needsReview) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Revisar',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captureState = context.watch<CaptureCubit>().state;
    final isCaptureActive =
        captureState.permission == CapturePermission.granted;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: isCaptureActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isCaptureActive
                        ? Icons.bolt_rounded
                        : Icons.receipt_long_outlined,
                    size: 38,
                    color: isCaptureActive
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isCaptureActive
                      ? 'Captura automática activa'
                      : 'Sin movimientos en este periodo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isCaptureActive
                      ? 'Flujo registrará tus Yapes, Plin y pagos bancarios automáticamente en cuanto ocurran.'
                      : 'Registra un movimiento manualmente o activa la captura automática de tus pagos.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (!isCaptureActive)
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.captureOnboarding),
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Activar captura automática'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => TransactionFormSheet.show(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Registrar movimiento manual'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
