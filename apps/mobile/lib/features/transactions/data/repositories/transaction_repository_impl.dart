import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_local_datasource.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';

/// Offline-first: la base local es la fuente de verdad de la UI y el remoto
/// solo la alimenta. Así la app funciona sin señal, que en móvil es lo normal.
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({
    required TransactionLocalDataSource local,
    required TransactionRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final TransactionLocalDataSource _local;
  final TransactionRemoteDataSource _remote;

  @override
  Stream<List<Transaction>> watchTransactions(TransactionFilter filter) {
    return _local
        .watchTransactions(filter)
        .map((models) => models.map((m) => m.toEntity()).toList())
        // Si dos emisiones son idénticas no repintamos.
        .distinct(_listEquals);
  }

  @override
  Stream<MonthlySummary> watchMonthlySummary(DateTime month) {
    final previous = DateTime(month.year, month.month - 1);

    // combineLatest: el resumen depende de dos streams a la vez y se
    // recalcula cuando cualquiera cambia.
    return Rx.combineLatest2<List<Transaction>, List<Transaction>,
        MonthlySummary>(
      watchTransactions(TransactionFilter(month: month)),
      watchTransactions(TransactionFilter(month: previous)),
      (current, prior) => _buildSummary(month, current, prior),
    ).distinct();
  }

  MonthlySummary _buildSummary(
    DateTime month,
    List<Transaction> current,
    List<Transaction> prior,
  ) {
    final expenses =
        current.where((t) => t.type == TransactionType.expense).toList();
    final priorExpenses =
        prior.where((t) => t.type == TransactionType.expense).toList();
    final income =
        current.where((t) => t.type == TransactionType.income).toList();

    final expenseTotal = expenses.fold<double>(0, (sum, t) => sum + t.amount);
    final previousExpenseTotal =
        priorExpenses.fold<double>(0, (sum, t) => sum + t.amount);
    final incomeTotal = income.fold<double>(0, (sum, t) => sum + t.amount);

    final grouped = <String, List<Transaction>>{};
    for (final t in expenses) {
      grouped.putIfAbsent(t.category.id, () => []).add(t);
    }

    final byCategory = grouped.entries.map((entry) {
      final subtotal = entry.value.fold<double>(0, (sum, t) => sum + t.amount);
      return CategoryTotal(
        category: entry.value.first.category,
        total: subtotal,
        share: expenseTotal == 0 ? 0 : subtotal / expenseTotal,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final daysElapsed = _daysElapsedIn(month);

    return MonthlySummary(
      month: month,
      total: expenseTotal,
      incomeTotal: incomeTotal,
      previousMonthTotal: previousExpenseTotal,
      byCategory: byCategory,
      dailyAverage: daysElapsed == 0 ? 0 : expenseTotal / daysElapsed,
    );
  }

  int _daysElapsedIn(DateTime month) {
    final now = DateTime.now();
    final isCurrentMonth = now.year == month.year && now.month == month.month;
    if (isCurrentMonth) return now.day;
    if (DateTime(month.year, month.month).isAfter(DateTime(now.year, now.month))) {
      return 0;
    }
    return DateTime(month.year, month.month + 1, 0).day;
  }

  @override
  Future<Result<Transaction>> addTransaction(Transaction transaction) async {
    try {
      // Escritura local primero: la UI responde al instante.
      final saved =
          await _local.upsert(TransactionModel.fromEntity(transaction));
      unawaitedSync();
      return Success(saved.toEntity());
    } on Object catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<Transaction>> updateTransaction(Transaction transaction) async {
    try {
      final saved =
          await _local.upsert(TransactionModel.fromEntity(transaction));
      unawaitedSync();
      return Success(saved.toEntity());
    } on Object catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteTransaction(String id) async {
    try {
      await _local.delete(id);
      unawaitedSync();
      return const Success(null);
    } on Object catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> syncPending() async {
    try {
      final pending = await _local.pendingSync();
      if (pending.isEmpty) return const Success(null);
      final acknowledged = await _remote.push(pending);
      await _local.markSynced(acknowledged);
      return const Success(null);
    } on DioException catch (e) {
      final message = e.type == DioExceptionType.connectionError
          ? 'Sin conexión para sincronizar. Se reintentará luego.'
          : (e.response?.data is Map && (e.response!.data as Map)['error'] != null
              ? (e.response!.data as Map)['error'].toString()
              : 'Error al sincronizar datos con el servidor.');
      return FailureResult(ServerFailure(message));
    } on Object catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  /// Sincroniza en segundo plano sin bloquear la respuesta a la UI.
  void unawaitedSync() {
    syncPending();
  }

  static bool _listEquals(List<Transaction> a, List<Transaction> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
