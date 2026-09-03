import 'package:equatable/equatable.dart';

import '../../domain/entities/recurring_expense.dart';

enum InsightsStatus { initial, loading, success, failure }

class InsightsState extends Equatable {
  const InsightsState({
    this.status = InsightsStatus.initial,
    this.recurringExpenses = const [],
    this.projection,
    this.errorMessage,
  });

  final InsightsStatus status;
  final List<RecurringExpense> recurringExpenses;
  final MonthlyProjection? projection;
  final String? errorMessage;

  InsightsState copyWith({
    InsightsStatus? status,
    List<RecurringExpense>? recurringExpenses,
    MonthlyProjection? projection,
    String? errorMessage,
  }) {
    return InsightsState(
      status: status ?? this.status,
      recurringExpenses: recurringExpenses ?? this.recurringExpenses,
      projection: projection ?? this.projection,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recurringExpenses,
        projection,
        errorMessage,
      ];
}
