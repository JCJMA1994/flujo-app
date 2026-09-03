import '../../../transactions/domain/entities/transaction.dart';
import '../entities/recurring_expense.dart';

class DetectRecurringExpenses {
  const DetectRecurringExpenses();

  List<RecurringExpense> call(List<Transaction> transactions) {
    final expenses = transactions.where((t) => t.isExpense && t.amount > 0).toList();

    // Agrupamos por comercio normalizado
    final byMerchant = <String, List<Transaction>>{};
    for (final tx in expenses) {
      final key = tx.merchant.trim().toLowerCase();
      if (key.isEmpty || key == 'sin identificar') continue;
      byMerchant.putIfAbsent(key, () => []).add(tx);
    }

    final detected = <RecurringExpense>[];

    for (final entry in byMerchant.entries) {
      final list = entry.value;
      if (list.length < 2) continue;

      // Ordenar por fecha cronológica ascendente
      list.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

      final intervals = <int>[];
      for (var i = 0; i < list.length - 1; i++) {
        final diffDays = list[i + 1].occurredAt.difference(list[i].occurredAt).inDays.abs();
        intervals.add(diffDays);
      }

      if (intervals.isEmpty) continue;

      final averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;

      final isMonthly = averageInterval >= 24 && averageInterval <= 36;
      final isWeekly = averageInterval >= 5 && averageInterval <= 10;

      if (!isMonthly && !isWeekly) continue;

      final totalAmount = list.fold<double>(0, (sum, t) => sum + t.amount);
      final avgAmount = totalAmount / list.length;

      // Verificar que los montos sean relativamente estables (desviación menor a 25%)
      final isConsistentAmount = list.every(
        (t) => (t.amount - avgAmount).abs() <= (avgAmount * 0.25 + 1.0),
      );

      if (!isConsistentAmount) continue;

      final lastTx = list.last;
      final frequency = isMonthly ? RecurringFrequency.monthly : RecurringFrequency.weekly;
      final nextDate = isMonthly
          ? DateTime(lastTx.occurredAt.year, lastTx.occurredAt.month + 1, lastTx.occurredAt.day)
          : lastTx.occurredAt.add(const Duration(days: 7));

      detected.add(
        RecurringExpense(
          merchant: lastTx.merchant,
          averageAmount: double.parse(avgAmount.toStringAsFixed(2)),
          currency: lastTx.currency,
          category: lastTx.category,
          frequency: frequency,
          lastOccurredAt: lastTx.occurredAt,
          estimatedNextDate: nextDate,
          occurrencesCount: list.length,
        ),
      );
    }

    // Ordenar por mayor impacto económico (monto promedio)
    detected.sort((a, b) => b.averageAmount.compareTo(a.averageAmount));
    return detected;
  }
}

class CalculateMonthlyProjection {
  const CalculateMonthlyProjection();

  MonthlyProjection call({
    required List<Transaction> currentMonthTransactions,
    required List<RecurringExpense> recurringExpenses,
    required DateTime targetMonth,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final daysInMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;

    final expenses = currentMonthTransactions.where((t) => t.isExpense && t.amount > 0).toList();
    final currentTotal = expenses.fold<double>(0, (sum, t) => sum + t.amount);

    int daysElapsed;
    if (effectiveNow.year == targetMonth.year && effectiveNow.month == targetMonth.month) {
      daysElapsed = effectiveNow.day.clamp(1, daysInMonth);
    } else if (targetMonth.isBefore(effectiveNow)) {
      daysElapsed = daysInMonth;
    } else {
      daysElapsed = 1;
    }

    final dailyBurnRate = currentTotal / daysElapsed;

    // Calcular qué gastos recurrentes aún no se han cobrado este mes
    double pendingRecurringTotal = 0;
    for (final recurring in recurringExpenses) {
      final alreadyCharged = expenses.any(
        (t) => t.merchant.trim().toLowerCase() == recurring.merchant.trim().toLowerCase(),
      );

      if (!alreadyCharged) {
        pendingRecurringTotal += recurring.averageAmount;
      }
    }

    double projectedTotal;
    if (daysElapsed >= daysInMonth) {
      projectedTotal = currentTotal;
    } else {
      final remainingDays = daysInMonth - daysElapsed;
      // Proyección: ritmo actual durante los días restantes + cobros pendientes identificados
      final variableProjected = dailyBurnRate * remainingDays;
      projectedTotal = currentTotal + variableProjected + (pendingRecurringTotal * 0.3);
    }

    return MonthlyProjection(
      currentTotal: double.parse(currentTotal.toStringAsFixed(2)),
      projectedTotal: double.parse(projectedTotal.toStringAsFixed(2)),
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
      dailyBurnRate: double.parse(dailyBurnRate.toStringAsFixed(2)),
      pendingRecurringTotal: double.parse(pendingRecurringTotal.toStringAsFixed(2)),
    );
  }
}
