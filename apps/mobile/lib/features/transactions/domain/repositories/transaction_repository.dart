import 'package:equatable/equatable.dart';

import '../../../../core/utils/result.dart';
import '../entities/transaction.dart';

class TransactionFilter extends Equatable {
  const TransactionFilter({
    this.month,
    this.categoryIds = const {},
    this.scope,
    this.type,
    this.parser,
    this.query = '',
    this.onlyNeedsReview = false,
  });

  final DateTime? month;
  final Set<String> categoryIds;
  final TransactionScope? scope;
  final TransactionType? type;
  final String? parser;
  final String query;
  final bool onlyNeedsReview;

  TransactionFilter copyWith({
    DateTime? month,
    Set<String>? categoryIds,
    TransactionScope? scope,
    TransactionType? type,
    String? parser,
    bool clearScope = false,
    bool clearType = false,
    bool clearParser = false,
    String? query,
    bool? onlyNeedsReview,
  }) {
    return TransactionFilter(
      month: month ?? this.month,
      categoryIds: categoryIds ?? this.categoryIds,
      scope: clearScope ? null : (scope ?? this.scope),
      type: clearType ? null : (type ?? this.type),
      parser: clearParser ? null : (parser ?? this.parser),
      query: query ?? this.query,
      onlyNeedsReview: onlyNeedsReview ?? this.onlyNeedsReview,
    );
  }

  @override
  List<Object?> get props =>
      [month, categoryIds, scope, type, parser, query, onlyNeedsReview];
}

/// El dominio define el contrato; `data` lo implementa. La inversión de
/// dependencias es lo que mantiene el dominio libre de Drift, Dio y Flutter.
abstract interface class TransactionRepository {
  /// Stream reactivo: la fuente de verdad es la base local, que se refresca
  /// cuando llega la sincronización o una notificación capturada.
  Stream<List<Transaction>> watchTransactions(TransactionFilter filter);

  Stream<MonthlySummary> watchMonthlySummary(DateTime month);

  Future<Result<Transaction>> addTransaction(Transaction transaction);

  Future<Transaction?> getTransaction(String id);

  Future<Result<Transaction>> updateTransaction(Transaction transaction);

  Future<Result<void>> deleteTransaction(String id);

  Future<Result<void>> syncPending();
}
