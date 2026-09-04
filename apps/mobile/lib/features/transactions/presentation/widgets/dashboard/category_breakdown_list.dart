import 'package:flutter/material.dart';

import '../../../domain/entities/transaction.dart';

class CategorySectionHeader extends StatelessWidget {
  const CategorySectionHeader({required this.count, super.key});

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

class CategoryBreakdownList extends StatelessWidget {
  const CategoryBreakdownList({required this.items, super.key});

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
