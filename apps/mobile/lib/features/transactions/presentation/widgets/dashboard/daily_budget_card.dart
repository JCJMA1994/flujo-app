import 'package:flutter/material.dart';

import '../../../domain/entities/transaction.dart';

class DailyBudgetCard extends StatelessWidget {
  const DailyBudgetCard({required this.summary, super.key});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasIncome = summary.incomeTotal > 0;
    final isPositive = summary.netBalance > 0;
    final daysRemaining = summary.daysRemaining;
    final dailyBudget = summary.recommendedDailyBudget;

    final statusColor = !hasIncome
        ? (isDark ? Colors.blueGrey.shade300 : Colors.blueGrey.shade700)
        : (isPositive
            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
            : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)));

    final cardBg = isDark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surface;

    final borderColor = isDark
        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PRESUPUESTO DIARIO SUGERIDO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  !hasIncome
                      ? 'Sin ingresos'
                      : (isPositive ? 'En meta' : 'Déficit'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'S/ ${dailyBudget.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                daysRemaining > 0 ? '/ día ($daysRemaining d restantes)' : '/ día',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            !hasIncome
                ? 'Registra tus ingresos de este mes para calcular tu ritmo de gasto diario disponible.'
                : (isPositive
                    ? 'Te quedan S/ ${summary.netBalance.toStringAsFixed(2)} de saldo a favor. Este ritmo te permite cerrar el mes con ahorro.'
                    : 'Has gastado S/ ${summary.netBalance.abs().toStringAsFixed(2)} más de tus ingresos. Modera gastos no esenciales.'),
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (hasIncome) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: summary.expenseRatio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  summary.expenseRatio > 0.9
                      ? Colors.redAccent
                      : (summary.expenseRatio > 0.7
                          ? Colors.orangeAccent
                          : Colors.teal),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consumido: ${(summary.expenseRatio * 100).toStringAsFixed(0)}% del ingreso',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Gasto: S/ ${summary.total.toStringAsFixed(0)} / S/ ${summary.incomeTotal.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
