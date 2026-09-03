import 'package:equatable/equatable.dart';

import '../../../transactions/domain/entities/transaction.dart';

enum RecurringFrequency {
  weekly,
  monthly,
}

class RecurringExpense extends Equatable {
  const RecurringExpense({
    required this.merchant,
    required this.averageAmount,
    required this.currency,
    required this.category,
    required this.frequency,
    required this.lastOccurredAt,
    required this.estimatedNextDate,
    required this.occurrencesCount,
  });

  final String merchant;
  final double averageAmount;
  final String currency;
  final Category category;
  final RecurringFrequency frequency;
  final DateTime lastOccurredAt;
  final DateTime estimatedNextDate;
  final int occurrencesCount;

  @override
  List<Object?> get props => [
        merchant,
        averageAmount,
        currency,
        category,
        frequency,
        lastOccurredAt,
        estimatedNextDate,
        occurrencesCount,
      ];
}

class MonthlyProjection extends Equatable {
  const MonthlyProjection({
    required this.currentTotal,
    required this.projectedTotal,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.dailyBurnRate,
    required this.pendingRecurringTotal,
  });

  final double currentTotal;
  final double projectedTotal;
  final int daysElapsed;
  final int daysInMonth;
  final double dailyBurnRate;
  final double pendingRecurringTotal;

  double get progressPercentage =>
      daysInMonth == 0 ? 0 : (daysElapsed / daysInMonth).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [
        currentTotal,
        projectedTotal,
        daysElapsed,
        daysInMonth,
        dailyBurnRate,
        pendingRecurringTotal,
      ];
}
