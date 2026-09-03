import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

/// Un caso de uso = una intención del usuario. Se invocan como funciones
/// (`watchTransactions(filter)`) gracias a `call`.
class WatchTransactions {
  const WatchTransactions(this._repository);

  final TransactionRepository _repository;

  Stream<List<Transaction>> call(TransactionFilter filter) =>
      _repository.watchTransactions(filter);
}

class WatchMonthlySummary {
  const WatchMonthlySummary(this._repository);

  final TransactionRepository _repository;

  Stream<MonthlySummary> call(DateTime month) =>
      _repository.watchMonthlySummary(month);
}

class AddTransaction {
  const AddTransaction(this._repository);

  final TransactionRepository _repository;

  Future<Result<Transaction>> call(Transaction transaction) {
    if (transaction.amount <= 0) {
      return Future.value(
        const FailureResult(ValidationFailure('El monto debe ser mayor a 0')),
      );
    }
    return _repository.addTransaction(transaction);
  }
}

/// Confirmar o corregir la categoría que asignó la IA. Es el gesto que
/// alimenta el aprendizaje de reglas del usuario.
class ReviewTransaction {
  const ReviewTransaction(this._repository);

  final TransactionRepository _repository;

  Future<Result<Transaction>> call(
    Transaction transaction, {
    Category? correctedCategory,
    TransactionScope? correctedScope,
  }) {
    return _repository.updateTransaction(
      transaction.copyWith(
        category: correctedCategory,
        scope: correctedScope,
        reviewed: true,
        confidence: 1,
      ),
    );
  }
}

class DeleteTransaction {
  const DeleteTransaction(this._repository);

  final TransactionRepository _repository;

  Future<Result<void>> call(String id) => _repository.deleteTransaction(id);
}

class SyncPendingTransactions {
  const SyncPendingTransactions(this._repository);

  final TransactionRepository _repository;

  Future<Result<void>> call() => _repository.syncPending();
}
