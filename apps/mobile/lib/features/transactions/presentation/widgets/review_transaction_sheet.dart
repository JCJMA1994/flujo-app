import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/flujo_feedback_modal.dart';
import '../../../capture/domain/entities/parsed_expense.dart';
import '../../../capture/presentation/cubit/capture_cubit.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/usecases.dart';
import '../cubit/privacy_cubit.dart';

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
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.transparent,
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

  bool get _hasChanges =>
      _selectedCategory.id != widget.transaction.category.id ||
      _selectedScope != widget.transaction.scope;

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

    if (result is FailureResult<Transaction>) {
      await FlujoFeedbackModal.showError(
        context,
        title: 'Error al verificar',
        message: result.failure.message,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    final isCategoryChanged =
        _selectedCategory.id != widget.transaction.category.id;
    final merchant = widget.transaction.merchant.trim();

    if (isCategoryChanged &&
        merchant.isNotEmpty &&
        merchant != 'Sin identificar') {
      final targetCat = _selectedCategory;
      final shouldCreateRule = await FlujoFeedbackModal.showConfirmation(
        context,
        title: '¿Crear regla automática?',
        message:
            '¿Deseas categorizar siempre los futuros movimientos de "$merchant" como ${targetCat.name}?',
        confirmLabel: 'Crear regla',
        cancelLabel: 'Ahora no',
        customIcon: LucideIcons.sparkles,
      );

      if ((shouldCreateRule ?? false) && mounted) {
        final newRule = UserRule(
          id: const Uuid().v4(),
          matcher: RuleMatcher.merchantContains,
          value: merchant,
          targetCategoryId: targetCat.id,
        );
        getIt<CaptureCubit>().addRule(newRule);
        if (mounted) {
          await FlujoFeedbackModal.showSuccess(
            context,
            title: 'Regla creada',
            message:
                'Los próximos movimientos de "$merchant" se clasificarán automáticamente como ${targetCat.name}.',
          );
        }
      }
    } else {
      if (mounted) {
        await FlujoFeedbackModal.showSuccess(
          context,
          title: '¡Movimiento verificado!',
          message:
              'El registro ha sido confirmado y clasificado en tus finanzas.',
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    final result = await getIt<ReviewTransaction>()(
      widget.transaction,
      correctedCategory: _selectedCategory,
      correctedScope: _selectedScope,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result is FailureResult<Transaction>) {
      await FlujoFeedbackModal.showError(
        context,
        title: 'Error al actualizar',
        message: result.failure.message,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    await FlujoFeedbackModal.showSuccess(
      context,
      title: 'Cambios guardados',
      message: 'Se actualizaron la categoría y el ámbito del movimiento.',
    );
  }

  Future<void> _delete() async {
    final confirm = await FlujoFeedbackModal.showConfirmation(
      context,
      title: '¿Eliminar movimiento?',
      message:
          '¿Estás seguro de que deseas eliminar este registro? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final result = await getIt<DeleteTransaction>()(widget.transaction.id);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result is FailureResult<void>) {
      await FlujoFeedbackModal.showError(
        context,
        title: 'Error al eliminar',
        message: result.failure.message,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    await FlujoFeedbackModal.showSuccess(
      context,
      title: 'Movimiento eliminado',
      message: 'El registro fue eliminado exitosamente.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tx = widget.transaction;
    final isIncome = tx.isIncome;
    final isReviewed = tx.reviewed;
    final isObscured =
        context.watch<PrivacyCubit?>()?.state.isObscured ?? false;
    final money = NumberFormat.currency(
      locale: 'es_PE',
      symbol: tx.currency == 'PEN' ? 'S/ ' : r'$ ',
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  color:
                      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Cabecera con tipo y estado
            Row(
              children: [
                // Tag Ingreso / Gasto
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isIncome
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
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
                const SizedBox(width: 8),

                // Tag Estado: VERIFICADO vs POR REVISAR
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isReviewed
                        ? (isDark
                            ? const Color(0xFF134E4A)
                            : const Color(0xFFCCFBF1))
                        : (isDark
                            ? const Color(0xFF451A03)
                            : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isReviewed
                          ? (isDark
                              ? const Color(0xFF2DD4BF)
                              : FlujoTokens.verdePetroleo)
                          : (isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706)),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReviewed
                            ? LucideIcons.circleCheck
                            : LucideIcons.alertCircle,
                        size: 12,
                        color: isReviewed
                            ? (isDark
                                ? const Color(0xFF2DD4BF)
                                : FlujoTokens.verdePetroleo)
                            : (isDark
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isReviewed ? 'VERIFICADO' : 'POR REVISAR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: isReviewed
                              ? (isDark
                                  ? const Color(0xFF2DD4BF)
                                  : FlujoTokens.verdePetroleo)
                              : (isDark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Botón cerrar
                IconButton.filledTonal(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Nombre y Monto
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.merchant.isNotEmpty ? tx.merchant : tx.category.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d MMMM yyyy, HH:mm', 'es')
                            .format(tx.occurredAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isObscured
                      ? '${isIncome ? '+' : '-'}••••'
                      : '${isIncome ? '+' : '-'}${money.format(tx.amount)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
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
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.bell,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tx.rawText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
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
                fontSize: 14,
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
                fontSize: 14,
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

            const SizedBox(height: 26),

            // Botón de acción principal
            if (!isReviewed) ...[
              SizedBox(
                height: FlujoTokens.alturaBoton,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FlujoTokens.verdePetroleo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        FlujoTokens.radioTarjetas,
                      ),
                    ),
                  ),
                  onPressed: _isLoading ? null : _confirmReview,
                  icon: const Icon(LucideIcons.checkCheck, size: 18),
                  label: const Text(
                    'Confirmar revisión',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                height: FlujoTokens.alturaBoton,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _hasChanges
                        ? FlujoTokens.verdePetroleo
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0)),
                    foregroundColor: _hasChanges
                        ? Colors.white
                        : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        FlujoTokens.radioTarjetas,
                      ),
                    ),
                  ),
                  onPressed: _isLoading
                      ? null
                      : (_hasChanges
                          ? _saveChanges
                          : () => Navigator.of(context).pop()),
                  icon: Icon(
                    _hasChanges ? LucideIcons.save : LucideIcons.check,
                    size: 18,
                  ),
                  label: Text(
                    _hasChanges ? 'Guardar cambios' : 'Listo',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Botón eliminar
            SizedBox(
              height: FlujoTokens.alturaBoton,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _delete,
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text(
                  'Eliminar registro',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      FlujoTokens.radioTarjetas,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
