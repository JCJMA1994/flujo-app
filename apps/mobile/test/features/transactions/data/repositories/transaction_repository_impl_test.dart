import 'package:flujo/core/error/failures.dart';
import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/transactions/data/datasources/transaction_local_datasource.dart';
import 'package:flujo/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:flujo/features/transactions/data/models/transaction_model.dart';
import 'package:flujo/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flujo/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDataSource extends Mock implements TransactionLocalDataSource {}

class MockRemoteDataSource extends Mock
    implements TransactionRemoteDataSource {}

void main() {
  late MockLocalDataSource local;
  late MockRemoteDataSource remote;
  late TransactionRepositoryImpl repository;

  const category = Category(id: 'food', name: 'Comida', emoji: '🍔');
  const salaryCategory = Category(id: 'salary', name: 'Sueldo', emoji: '💰');

  final tx = Transaction(
    id: 'tx-1',
    amount: 25,
    currency: 'PEN',
    merchant: 'Starbucks',
    occurredAt: DateTime(2026, 9),
    category: category,
    source: TransactionSource.manual,
    scope: TransactionScope.personal,
  );

  final incomeTx = Transaction(
    id: 'tx-2',
    amount: 3000,
    currency: 'PEN',
    merchant: 'Empresa',
    occurredAt: DateTime(2026, 9),
    category: salaryCategory,
    source: TransactionSource.manual,
    scope: TransactionScope.personal,
    type: TransactionType.income,
  );

  final model = TransactionModel.fromEntity(tx);
  final incomeModel = TransactionModel.fromEntity(incomeTx);

  setUpAll(() {
    registerFallbackValue(const TransactionFilter());
    registerFallbackValue(model);
  });

  setUp(() {
    local = MockLocalDataSource();
    remote = MockRemoteDataSource();
    repository = TransactionRepositoryImpl(local: local, remote: remote);
  });

  group('TransactionRepositoryImpl', () {
    test('watchTransactions mapea modelos a entidades del dominio', () {
      when(() => local.watchTransactions(any()))
          .thenAnswer((_) => Stream.value([model]));

      expect(
        repository.watchTransactions(const TransactionFilter()),
        emits([tx]),
      );
    });

    test('watchMonthlySummary calcula total de gastos, ingresos y balance neto',
        () async {
      when(() => local.watchTransactions(any()))
          .thenAnswer((_) => Stream.value([model, incomeModel]));

      final summaryStream = repository.watchMonthlySummary(DateTime(2026, 9));

      expect(
        summaryStream,
        emits(
          predicate<MonthlySummary>((s) {
            return s.total == 25 &&
                s.incomeTotal == 3000 &&
                s.netBalance == 2975 &&
                s.daysInMonth == 30 &&
                s.daysRemaining > 0 &&
                s.recommendedDailyBudget > 0 &&
                s.expenseRatio > 0 &&
                s.byCategory.length == 1 &&
                s.byCategory.first.category == category;
          }),
        ),
      );
    });

    test(
        'watchMonthlySummary maneja mes futuro correctamente con dailyAverage 0',
        () async {
      when(() => local.watchTransactions(any()))
          .thenAnswer((_) => Stream.value([]));

      final futureMonth = DateTime(2099);
      final summaryStream = repository.watchMonthlySummary(futureMonth);

      expect(
        summaryStream,
        emits(
          predicate<MonthlySummary>((s) {
            return s.total == 0 &&
                s.dailyAverage == 0 &&
                s.daysInMonth == 31 &&
                s.daysRemaining == 31 &&
                s.recommendedDailyBudget == 0;
          }),
        ),
      );
    });

    test('addTransaction guarda localmente y retorna Success', () async {
      when(() => local.upsert(any())).thenAnswer((_) async => model);
      when(() => local.pendingSync()).thenAnswer((_) async => []);

      final result = await repository.addTransaction(tx);

      expect(result, isA<Success<Transaction>>());
      expect((result as Success<Transaction>).value, tx);
      verify(() => local.upsert(any())).called(1);
    });

    test('deleteTransaction realiza borrado lógico en local', () async {
      when(() => local.delete(any())).thenAnswer((_) async {});
      when(() => local.pendingSync()).thenAnswer((_) async => []);

      final result = await repository.deleteTransaction('tx-1');

      expect(result, isA<Success<void>>());
      verify(() => local.delete('tx-1')).called(1);
    });

    test('syncPending envía pendientes y marca confirmados en local', () async {
      when(() => local.pendingSync()).thenAnswer((_) async => [model]);
      when(() => remote.push(any())).thenAnswer((_) async => ['tx-1']);
      when(() => local.markSynced(any())).thenAnswer((_) async {});

      final result = await repository.syncPending();

      expect(result, isA<Success<void>>());
      verify(() => remote.push([model])).called(1);
      verify(() => local.markSynced(['tx-1'])).called(1);
    });

    test('syncPending retorna ServerFailure si remote falla', () async {
      when(() => local.pendingSync()).thenAnswer((_) async => [model]);
      when(() => remote.push(any())).thenThrow(Exception('Network timeout'));

      final result = await repository.syncPending();

      expect(result, isA<FailureResult<void>>());
      expect((result as FailureResult<void>).failure, isA<ServerFailure>());
    });
  });
}
