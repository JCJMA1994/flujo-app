import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../domain/usecases/insights_usecases.dart';
import 'insights_state.dart';

class InsightsCubit extends Cubit<InsightsState> {
  InsightsCubit({
    required TransactionRepository repository,
    required DetectRecurringExpenses detectRecurringExpenses,
    required CalculateMonthlyProjection calculateMonthlyProjection,
  })  : _repository = repository,
        _detectRecurringExpenses = detectRecurringExpenses,
        _calculateMonthlyProjection = calculateMonthlyProjection,
        super(const InsightsState());

  final TransactionRepository _repository;
  final DetectRecurringExpenses _detectRecurringExpenses;
  final CalculateMonthlyProjection _calculateMonthlyProjection;

  StreamSubscription<List<Transaction>>? _subscription;
  DateTime _currentMonth = DateTime.now();

  void start({DateTime? initialMonth}) {
    if (initialMonth != null) {
      _currentMonth = initialMonth;
    }
    emit(state.copyWith(status: InsightsStatus.loading));

    _subscription?.cancel();
    _subscription = _repository
        .watchTransactions(const TransactionFilter())
        .listen(_onTransactionsEmitted, onError: _onError);
  }

  void updateMonth(DateTime month) {
    _currentMonth = month;
    if (_lastTransactions != null) {
      _processInsights(_lastTransactions!);
    }
  }

  List<Transaction>? _lastTransactions;

  void _onTransactionsEmitted(List<Transaction> transactions) {
    _lastTransactions = transactions;
    _processInsights(transactions);
  }

  void _processInsights(List<Transaction> transactions) {
    try {
      final recurring = _detectRecurringExpenses(transactions);

      final currentMonthTransactions = transactions.where((t) {
        return t.occurredAt.year == _currentMonth.year &&
            t.occurredAt.month == _currentMonth.month;
      }).toList();

      final projection = _calculateMonthlyProjection(
        currentMonthTransactions: currentMonthTransactions,
        recurringExpenses: recurring,
        targetMonth: _currentMonth,
      );

      emit(
        state.copyWith(
          status: InsightsStatus.success,
          recurringExpenses: recurring,
          projection: projection,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: InsightsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onError(Object error) {
    emit(
      state.copyWith(
        status: InsightsStatus.failure,
        errorMessage: error.toString(),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
