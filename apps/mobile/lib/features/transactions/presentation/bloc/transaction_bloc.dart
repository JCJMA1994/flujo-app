import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/usecases.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

/// Transformer de rxdart: espera a que el usuario deje de escribir antes de
/// consultar. Sin esto se dispara una query por cada tecla.
EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounceTime(duration).switchMap(mapper);
}

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc({
    required WatchTransactions watchTransactions,
    required DeleteTransaction deleteTransaction,
    required SyncPendingTransactions syncPendingTransactions,
  })  : _watchTransactions = watchTransactions,
        _deleteTransaction = deleteTransaction,
        _syncPendingTransactions = syncPendingTransactions,
        super(const TransactionState()) {
    on<TransactionsSubscriptionRequested>(_onSubscriptionRequested);
    on<_TransactionsUpdated>(_onTransactionsUpdated);
    on<_TransactionsFailed>(_onTransactionsFailed);
    on<TransactionSyncRequested>(
      _onSyncRequested,
      transformer: droppable(),
    );

    // Solo la búsqueda lleva debounce; los demás filtros son toques discretos.
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: debounce(const Duration(milliseconds: 350)),
    );
    on<MonthChanged>(_onMonthChanged, transformer: restartable());
    on<ScopeFilterChanged>(_onScopeChanged, transformer: restartable());
    on<TypeFilterChanged>(_onTypeChanged, transformer: restartable());
    on<ParserFilterChanged>(_onParserChanged, transformer: restartable());
    on<CategoryFilterToggled>(_onCategoryToggled, transformer: restartable());
    on<TransactionDeleted>(_onDeleted, transformer: sequential());
  }

  final WatchTransactions _watchTransactions;
  final DeleteTransaction _deleteTransaction;
  final SyncPendingTransactions _syncPendingTransactions;

  /// El filtro vive como stream para poder aplicarle `switchMap`: cada cambio
  /// cancela la suscripción anterior y abre una nueva al repositorio.
  final _filterSubject = BehaviorSubject<TransactionFilter>.seeded(
    const TransactionFilter(),
  );

  StreamSubscription<List<Transaction>>? _subscription;

  Future<void> _onSubscriptionRequested(
    TransactionsSubscriptionRequested event,
    Emitter<TransactionState> emit,
  ) async {
    emit(state.copyWith(status: TransactionStatus.loading));

    await _subscription?.cancel();
    _subscription =
        _filterSubject.distinct().switchMap(_watchTransactions.call).listen(
              (transactions) => add(_TransactionsUpdated(transactions)),
              onError: (Object error) =>
                  add(_TransactionsFailed(CacheFailure(error.toString()))),
            );
  }

  void _onTransactionsUpdated(
    _TransactionsUpdated event,
    Emitter<TransactionState> emit,
  ) {
    emit(
      state.copyWith(
        status: TransactionStatus.success,
        transactions: event.transactions,
        clearFailure: true,
      ),
    );
  }

  void _onTransactionsFailed(
    _TransactionsFailed event,
    Emitter<TransactionState> emit,
  ) {
    emit(
      state.copyWith(
        status: TransactionStatus.failure,
        failure: event.failure,
      ),
    );
  }

  void _updateFilter(
    Emitter<TransactionState> emit,
    TransactionFilter filter,
  ) {
    _filterSubject.add(filter);
    emit(state.copyWith(filter: filter));
  }

  void _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<TransactionState> emit,
  ) {
    _updateFilter(emit, state.filter.copyWith(query: event.query.trim()));
  }

  void _onMonthChanged(MonthChanged event, Emitter<TransactionState> emit) {
    _updateFilter(emit, state.filter.copyWith(month: event.month));
  }

  void _onScopeChanged(
    ScopeFilterChanged event,
    Emitter<TransactionState> emit,
  ) {
    _updateFilter(
      emit,
      state.filter.copyWith(
        scope: event.scope,
        clearScope: event.scope == null,
      ),
    );
  }

  void _onTypeChanged(
    TypeFilterChanged event,
    Emitter<TransactionState> emit,
  ) {
    _updateFilter(
      emit,
      state.filter.copyWith(
        type: event.type,
        clearType: event.type == null,
      ),
    );
  }

  void _onParserChanged(
    ParserFilterChanged event,
    Emitter<TransactionState> emit,
  ) {
    _updateFilter(
      emit,
      state.filter.copyWith(
        parser: event.parser,
        clearParser: event.parser == null,
      ),
    );
  }

  void _onCategoryToggled(
    CategoryFilterToggled event,
    Emitter<TransactionState> emit,
  ) {
    final ids = Set<String>.from(state.filter.categoryIds);
    ids.contains(event.categoryId)
        ? ids.remove(event.categoryId)
        : ids.add(event.categoryId);
    _updateFilter(emit, state.filter.copyWith(categoryIds: ids));
  }

  Future<void> _onSyncRequested(
    TransactionSyncRequested event,
    Emitter<TransactionState> emit,
  ) async {
    emit(state.copyWith(isSyncing: true));
    final result = await _syncPendingTransactions();
    result.fold(
      onFailure: (failure) => emit(
        state.copyWith(
          isSyncing: false,
          failure: failure,
        ),
      ),
      onSuccess: (_) => emit(state.copyWith(isSyncing: false)),
    );
  }

  Future<void> _onDeleted(
    TransactionDeleted event,
    Emitter<TransactionState> emit,
  ) async {
    final result = await _deleteTransaction(event.id);
    result.fold(
      onFailure: (failure) => emit(state.copyWith(failure: failure)),
      // No emitimos la lista: el stream del repositorio la refresca solo.
      onSuccess: (_) {},
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _filterSubject.close();
    return super.close();
  }
}
