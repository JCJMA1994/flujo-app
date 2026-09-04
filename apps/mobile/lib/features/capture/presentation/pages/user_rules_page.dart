import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/parsed_expense.dart';
import '../cubit/capture_cubit.dart';

class UserRulesPage extends StatelessWidget {
  const UserRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reglas de categorización'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: BlocBuilder<CaptureCubit, CaptureState>(
            buildWhen: (prev, curr) => prev.rules != curr.rules,
            builder: (context, state) {
              if (state.rules.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_fix_high_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No tienes reglas automáticas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea reglas personalizadas para asignar categorías en automático cuando te llegue una notificación de Yape o bancos.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => _showAddRuleSheet(context),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Crear primera regla'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.rules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rule = state.rules[index];
                  final category = kDefaultCategories.firstWhere(
                    (c) => c.id == rule.targetCategoryId,
                    orElse: () => const Category(
                      id: 'other',
                      name: 'Otros',
                      emoji: '💸',
                    ),
                  );

                  final description = switch (rule.matcher) {
                    RuleMatcher.merchantContains =>
                      'Si el comercio contiene "${rule.value}"',
                    RuleMatcher.amountBelow =>
                      'Si el monto es menor a S/ ${rule.value}',
                    RuleMatcher.amountAbove =>
                      'Si el monto es mayor a S/ ${rule.value}',
                  };

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        child: Text(
                          category.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      title: Text(
                        description,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Categoría: ${category.name}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Eliminar regla',
                        onPressed: () {
                          final updated = List<UserRule>.from(state.rules)
                            ..removeAt(index);
                          context.read<CaptureCubit>().loadRules(updated);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRuleSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva regla'),
      ),
    );
  }

  void _showAddRuleSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => _AddRuleSheet(
        onRuleCreated: (newRule) {
          final cubit = context.read<CaptureCubit>();
          cubit.loadRules([...cubit.state.rules, newRule]);
        },
      ),
    );
  }
}

class _AddRuleSheet extends StatefulWidget {
  const _AddRuleSheet({required this.onRuleCreated});

  final ValueChanged<UserRule> onRuleCreated;

  @override
  State<_AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends State<_AddRuleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  RuleMatcher _matcher = RuleMatcher.merchantContains;
  Category _targetCategory = kDefaultCategories.first;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final rule = UserRule(
      id: const Uuid().v4(),
      matcher: _matcher,
      value: _valueController.text.trim(),
      targetCategoryId: _targetCategory.id,
    );

    widget.onRuleCreated(rule);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nueva regla de gasto', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<RuleMatcher>(
                initialValue: _matcher,
                decoration: const InputDecoration(
                  labelText: 'Condición',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: RuleMatcher.merchantContains,
                    child: Text('El nombre del comercio contiene...'),
                  ),
                  DropdownMenuItem(
                    value: RuleMatcher.amountBelow,
                    child: Text('El monto es menor a...'),
                  ),
                  DropdownMenuItem(
                    value: RuleMatcher.amountAbove,
                    child: Text('El monto es mayor a...'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _matcher = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(
                  labelText: _matcher == RuleMatcher.merchantContains
                      ? 'Texto o palabra clave'
                      : 'Monto límite en soles',
                  hintText: _matcher == RuleMatcher.merchantContains
                      ? 'Ej. Starbucks, Rappi, Bodega'
                      : 'Ej. 5.00',
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa un valor para la condición';
                  }
                  if (_matcher != RuleMatcher.merchantContains) {
                    final num = double.tryParse(val.trim());
                    if (num == null || num <= 0) {
                      return 'Monto numérico inválido';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Asignar a categoría', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in kDefaultCategories)
                    ChoiceChip(
                      label: Text('${category.emoji} ${category.name}'),
                      selected: _targetCategory.id == category.id,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _targetCategory = category);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: const Text('Crear regla'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
