import 'package:bloc_test/bloc_test.dart';
import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flujo/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:flujo/features/transactions/domain/usecases/usecases.dart';
import 'package:flujo/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWatchTransactions extends Mock implements WatchTransactions {}

class MockDeleteTransaction extends Mock implements DeleteTransaction {}

class MockSyncPendingTransactions extends Mock
    implements SyncPendingTransactions {}

void main() {
  late MockWatchTransactions watchTransactions;
  late MockDeleteTransaction deleteTransaction;
  late MockSyncPendingTransactions syncPendingTransactions;

  const category = Category(id: 'food', name: 'Comida', emoji: '🍔');

  final tx = Transaction(
    id: '1',
    amount: 24.5,
    currency: 'PEN',
    merchant: 'Starbucks',
    occurredAt: DateTime(2026, 9),
    category: category,
    source: TransactionSource.bankNotification,
    scope: TransactionScope.personal,
  );

  setUpAll(() => registerFallbackValue(const TransactionFilter()));

  setUp(() {
    watchTransactions = MockWatchTransactions();
    deleteTransaction = MockDeleteTransaction();
    syncPendingTransactions = MockSyncPendingTransactions();
  });

  blocTest<TransactionBloc, TransactionState>(
    'emite loading y luego success con las transacciones del stream',
    setUp: () {
      when(() => watchTransactions(any()))
          .thenAnswer((_) => Stream.value([tx]));
    },
    build: () => TransactionBloc(
      watchTransactions: watchTransactions,
      deleteTransaction: deleteTransaction,
      syncPendingTransactions: syncPendingTransactions,
    ),
    act: (bloc) => bloc.add(const TransactionsSubscriptionRequested()),
    expect: () => [
      const TransactionState(status: TransactionStatus.loading),
      TransactionState(
        status: TransactionStatus.success,
        transactions: [tx],
      ),
    ],
  );

  blocTest<TransactionBloc, TransactionState>(
    'aplica debounce y solo consulta con el último texto escrito',
    setUp: () {
      when(() => watchTransactions(any()))
          .thenAnswer((_) => Stream.value([tx]));
    },
    build: () => TransactionBloc(
      watchTransactions: watchTransactions,
      deleteTransaction: deleteTransaction,
      syncPendingTransactions: syncPendingTransactions,
    ),
    act: (bloc) => bloc
      ..add(const SearchQueryChanged('s'))
      ..add(const SearchQueryChanged('st'))
      ..add(const SearchQueryChanged('star')),
    wait: const Duration(milliseconds: 500),
    verify: (bloc) {
      expect(bloc.state.filter.query, 'star');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'sincroniza pendientes al emitir TransactionSyncRequested',
    setUp: () {
      when(() => syncPendingTransactions())
          .thenAnswer((_) async => const Success(null));
    },
    build: () => TransactionBloc(
      watchTransactions: watchTransactions,
      deleteTransaction: deleteTransaction,
      syncPendingTransactions: syncPendingTransactions,
    ),
    act: (bloc) => bloc.add(const TransactionSyncRequested()),
    expect: () => [
      const TransactionState(isSyncing: true),
      const TransactionState(),
    ],
    verify: (_) {
      verify(() => syncPendingTransactions()).called(1);
    },
  );
}
