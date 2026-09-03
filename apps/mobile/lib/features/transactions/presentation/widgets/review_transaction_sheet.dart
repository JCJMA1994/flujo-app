import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../capture/domain/entities/parsed_expense.dart';
import '../../../capture/presentation/cubit/capture_cubit.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/usecases.dart';

class ReviewTransactionSheet extends StatefulWidget {
  const ReviewTransactionSheet({
    required this.transaction,
    super.key,
  });

  final Transaction transaction;

  static Future<void> show(BuildContext context, Transaction transaction) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReviewTransactionSheet(transaction: transaction),
    );
  }

  @override
  State<ReviewTransactionSheet> createState() => _ReviewTransactionSheetState();
}

class _ReviewTransactionSheetState extends State<ReviewTransactionSheet> {
  late Category _selectedCategory;
  late TransactionScope _selectedScope;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.transaction.category;
    _selectedScope = widget.transaction.scope;
  }

  List<Category> get _availableCategories =>
      widget.transaction.type == TransactionType.expense
          ? kExpenseCategories
          : kIncomeCategories;

  Future<void> _confirmReview() async {
    setState(() => _isLoading = true);

    final result = await getIt<ReviewTransaction>()(
      widget.transaction,
      correctedCategory: _selectedCategory,
      correctedScope: _selectedScope,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      onFailure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      onSuccess: (_) {
        Navigator.of(context).pop();
        final isCategoryChanged =
            _selectedCategory != widget.transaction.category;
        final merchant = widget.transaction.merchant.trim();

        if (isCategoryChanged &&
            merchant.isNotEmpty &&
            merchant != 'Sin identificar') {
          final targetCat = _selectedCategory;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¿Categorizar siempre "$merchant" como ${targetCat.name}?',
              ),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'CREAR REGLA',
                onPressed: () {
                  final newRule = UserRule(
                    id: const Uuid().v4(),
                    matcher: RuleMatcher.merchantContains,
                    value: merchant,
                    targetCategoryId: targetCat.id,
                  );
                  getIt<CaptureCubit>().addRule(newRule);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Regla creada para "$merchant"'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Movimiento verificado')),
          );
        }
      },
    );
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este movimiento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final result = await getIt<DeleteTransaction>()(widget.transaction.id);

    if (!mounted) return;
    setState(() => _isLoading = false);

    result.fold(
      onFailure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      onSuccess: (_) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro eliminado')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tx = widget.transaction;
    final isIncome = tx.isIncome;
    final money = NumberFormat.currency(
      locale: 'es_PE',
      symbol: tx.currency == 'PEN' ? 'S/ ' : r'$ ',
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isIncome
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isIncome ? 'INGRESO' : 'GASTO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tx.merchant,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('d MMMM yyyy, HH:mm', 'es')
                            .format(tx.occurredAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${money.format(tx.amount)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isIncome ? Colors.green : null,
                  ),
                ),
              ],
            ),
            if (tx.rawText != null && tx.rawText!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tx.rawText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Categoría',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in _availableCategories)
                  ChoiceChip(
                    label: Text('${category.emoji} ${category.name}'),
                    selected: _selectedCategory.id == category.id,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ámbito',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Personal'),
                  selected: _selectedScope == TransactionScope.personal,
                  onSelected: (selected) {
                    if (selected) {
                      setState(
                        () => _selectedScope = TransactionScope.personal,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Negocio'),
                  selected: _selectedScope == TransactionScope.business,
                  onSelected: (selected) {
                    if (selected) {
                      setState(
                        () => _selectedScope = TransactionScope.business,
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isLoading ? null : _confirmReview,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirmar revisión'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Eliminar registro'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
