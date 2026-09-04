part of 'transaction_bloc.dart';

enum TransactionStatus { initial, loading, success, failure }

final class TransactionState extends Equatable {
  const TransactionState({
    this.status = TransactionStatus.initial,
    this.transactions = const [],
    this.filter = const TransactionFilter(),
    this.failure,
    this.isSyncing = false,
  });

  final TransactionStatus status;
  final List<Transaction> transactions;
  final TransactionFilter filter;
  final Failure? failure;
  final bool isSyncing;

  List<Transaction> get pendingReview =>
      transactions.where((t) => t.needsReview).toList();

  double get total => transactions.fold<double>(0, (sum, t) => sum + t.amount);

  TransactionState copyWith({
    TransactionStatus? status,
    List<Transaction>? transactions,
    TransactionFilter? filter,
    Failure? failure,
    bool? isSyncing,
    bool clearFailure = false,
  }) {
    return TransactionState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      filter: filter ?? this.filter,
      failure: clearFailure ? null : (failure ?? this.failure),
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }

  @override
  List<Object?> get props => [status, transactions, filter, failure, isSyncing];
}
