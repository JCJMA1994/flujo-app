import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../cubit/insights_cubit.dart';
import '../cubit/insights_state.dart';

class InsightsCard extends StatelessWidget {
  const InsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat =
        NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return BlocBuilder<InsightsCubit, InsightsState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.projection != curr.projection ||
          prev.recurringExpenses != curr.recurringExpenses,
      builder: (context, state) {
        if (state.status == InsightsStatus.loading ||
            state.status == InsightsStatus.initial) {
          return const SizedBox.shrink();
        }

        final projection = state.projection;
        if (projection == null || projection.currentTotal == 0) {
          return const SizedBox.shrink();
        }

        final recurring = state.recurringExpenses;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proyección de Fin de Mes',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Día ${projection.daysElapsed} de ${projection.daysInMonth} · Ritmo: ${currencyFormat.format(projection.dailyBurnRate)}/día',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: projection.progressPercentage,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gasto estimado al cierre:',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      currencyFormat.format(projection.projectedTotal),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                if (recurring.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pagos recurrentes detectados (${recurring.length})',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: recurring.map((rec) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            avatar: Text(rec.category.emoji),
                            label: Text(
                              '${rec.merchant}: ${currencyFormat.format(rec.averageAmount)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            backgroundColor: theme.colorScheme.surface,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
