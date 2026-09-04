part of 'transaction_bloc.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

/// Arranca la suscripción al stream del repositorio.
final class TransactionsSubscriptionRequested extends TransactionEvent {
  const TransactionsSubscriptionRequested();
}

/// Dispara la sincronización con el backend para transacciones pendientes.
final class TransactionSyncRequested extends TransactionEvent {
  const TransactionSyncRequested();
}

/// Emitido internamente cuando el stream entrega datos nuevos.
final class _TransactionsUpdated extends TransactionEvent {
  const _TransactionsUpdated(this.transactions);

  final List<Transaction> transactions;

  @override
  List<Object?> get props => [transactions];
}

final class _TransactionsFailed extends TransactionEvent {
  const _TransactionsFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class SearchQueryChanged extends TransactionEvent {
  const SearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class MonthChanged extends TransactionEvent {
  const MonthChanged(this.month);

  final DateTime month;

  @override
  List<Object?> get props => [month];
}

final class ScopeFilterChanged extends TransactionEvent {
  const ScopeFilterChanged(this.scope);

  final TransactionScope? scope;

  @override
  List<Object?> get props => [scope];
}

final class CategoryFilterToggled extends TransactionEvent {
  const CategoryFilterToggled(this.categoryId);

  final String categoryId;

  @override
  List<Object?> get props => [categoryId];
}

final class TransactionDeleted extends TransactionEvent {
  const TransactionDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
