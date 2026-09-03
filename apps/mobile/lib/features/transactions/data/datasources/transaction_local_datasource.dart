import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

/// Implementa esto con Drift. La firma devuelve streams porque Drift expone
/// `watch()` sobre las queries y así el repositorio no hace polling.
abstract interface class TransactionLocalDataSource {
  Stream<List<TransactionModel>> watchTransactions(TransactionFilter filter);

  Future<TransactionModel> upsert(TransactionModel model);

  Future<void> delete(String id);

  /// Transacciones creadas o editadas offline, aún no confirmadas por el server.
  Future<List<TransactionModel>> pendingSync();

  Future<void> markSynced(List<String> ids);
}
