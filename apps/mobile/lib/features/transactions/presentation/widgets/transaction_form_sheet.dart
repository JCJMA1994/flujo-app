import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/usecases.dart';

class TransactionFormSheet extends StatefulWidget {
  const TransactionFormSheet({
    super.key,
    this.initialTransaction,
  });

  final Transaction? initialTransaction;

  static Future<void> show(BuildContext context, [Transaction? initial]) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TransactionFormSheet(initialTransaction: initial),
    );
  }

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;

  late TransactionType _selectedType;
  late Category _selectedCategory;
  late TransactionScope _selectedScope;
  late DateTime _occurredAt;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    _amountController = TextEditingController(
      text: tx != null ? tx.amount.toStringAsFixed(2) : '',
    );
    _merchantController = TextEditingController(
      text: tx?.merchant ?? '',
    );
    _selectedType = tx?.type ?? TransactionType.expense;
    _selectedCategory = tx?.category ??
        (_selectedType == TransactionType.expense
            ? kExpenseCategories.first
            : kIncomeCategories.first);
    _selectedScope = tx?.scope ?? TransactionScope.personal;
    _occurredAt = tx?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  List<Category> get _availableCategories =>
      _selectedType == TransactionType.expense
          ? kExpenseCategories
          : kIncomeCategories;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;

    await HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final isEditing = widget.initialTransaction != null;
    final tx = Transaction(
      id: widget.initialTransaction?.id ?? const Uuid().v4(),
      amount: amount,
      currency: widget.initialTransaction?.currency ?? 'PEN',
      merchant: _merchantController.text.trim(),
      occurredAt: _occurredAt,
      category: _selectedCategory,
      source: widget.initialTransaction?.source ?? TransactionSource.manual,
      scope: _selectedScope,
      type: _selectedType,
    );

    final result = isEditing
        ? await getIt<ReviewTransaction>()(
            tx,
            correctedCategory: _selectedCategory,
            correctedScope: _selectedScope,
          )
        : await getIt<AddTransaction>()(tx);

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
          SnackBar(
            content: Text(
              isEditing
                  ? 'Transacción actualizada'
                  : (_selectedType == TransactionType.income
                      ? 'Ingreso registrado con éxito'
                      : 'Gasto registrado con éxito'),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialTransaction != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 12,
      ),
      child: Form(
        key: _formKey,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Editar movimiento' : 'Nuevo movimiento',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Gasto'),
                    icon: Icon(Icons.arrow_downward_rounded, color: Colors.red),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Ingreso'),
                    icon: Icon(Icons.arrow_upward_rounded, color: Colors.green),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (set) {
                  HapticFeedback.selectionClick();
                  final newType = set.first;
                  setState(() {
                    _selectedType = newType;
                    _selectedCategory = newType == TransactionType.expense
                        ? kExpenseCategories.first
                        : kIncomeCategories.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto en soles',
                  prefixText: 'S/ ',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un monto válido';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Monto inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final preset in [5, 10, 20, 50, 100])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.add_rounded, size: 14),
                          label: Text('S/ $preset'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            final current = double.tryParse(
                                  _amountController.text.trim(),
                                ) ??
                                0;

                            final next = current > 0
                                ? current + preset
                                : preset.toDouble();
                            _amountController.text = next.toStringAsFixed(2);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _merchantController,
                decoration: InputDecoration(
                  labelText: _selectedType == TransactionType.income
                      ? 'Origen o contacto'
                      : 'Comercio o concepto',
                  hintText: _selectedType == TransactionType.income
                      ? 'Ej. Sueldo, Depósito Juan, Cliente'
                      : 'Ej. Tambo, Starbucks, Bodega',
                  prefixIcon: Icon(
                    _selectedType == TransactionType.income
                        ? Icons.person_outline_rounded
                        : Icons.storefront_outlined,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa el concepto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEditing
                            ? 'Guardar cambios'
                            : (_selectedType == TransactionType.income
                                ? 'Registrar ingreso'
                                : 'Registrar gasto'),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
