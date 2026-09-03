import 'package:flujo/features/insights/domain/entities/recurring_expense.dart';
import 'package:flujo/features/insights/domain/usecases/insights_usecases.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DetectRecurringExpenses', () {
    const detector = DetectRecurringExpenses();

    test('detecta suscripción mensual de Netflix con 3 pagos consecutivos', () {
      final transactions = [
        Transaction(
          id: 'tx-1',
          amount: 44.90,
          currency: 'PEN',
          merchant: 'Netflix',
          occurredAt: DateTime(2026, 1, 15),
          category: const Category(id: 'subscriptions', name: 'Suscripciones', emoji: '🍿'),
          source: TransactionSource.bankNotification,
          scope: TransactionScope.personal,
        ),
        Transaction(
          id: 'tx-2',
          amount: 44.90,
          currency: 'PEN',
          merchant: 'Netflix',
          occurredAt: DateTime(2026, 2, 15),
          category: const Category(id: 'subscriptions', name: 'Suscripciones', emoji: '🍿'),
          source: TransactionSource.bankNotification,
          scope: TransactionScope.personal,
        ),
        Transaction(
          id: 'tx-3',
          amount: 44.90,
          currency: 'PEN',
          merchant: 'Netflix',
          occurredAt: DateTime(2026, 3, 16),
          category: const Category(id: 'subscriptions', name: 'Suscripciones', emoji: '🍿'),
          source: TransactionSource.bankNotification,
          scope: TransactionScope.personal,
        ),
      ];

      final result = detector(transactions);

      expect(result.length, equals(1));
      expect(result.first.merchant, equals('Netflix'));
      expect(result.first.averageAmount, equals(44.90));
      expect(result.first.frequency, equals(RecurringFrequency.monthly));
      expect(result.first.occurrencesCount, equals(3));
    });

    test('descarta compras esporádicas no recurrentes', () {
      final transactions = [
        Transaction(
          id: 'tx-1',
          amount: 250,
          currency: 'PEN',
          merchant: 'Zara',
          occurredAt: DateTime(2026, 1, 5),
          category: const Category(id: 'shopping', name: 'Compras', emoji: '🛍️'),
          source: TransactionSource.manual,
          scope: TransactionScope.personal,
        ),
        Transaction(
          id: 'tx-2',
          amount: 15,
          currency: 'PEN',
          merchant: 'Bembos',
          occurredAt: DateTime(2026, 2, 10),
          category: const Category(id: 'food', name: 'Comida', emoji: '🍔'),
          source: TransactionSource.bankNotification,
          scope: TransactionScope.personal,
        ),
      ];

      final result = detector(transactions);
      expect(result, isEmpty);
    });

    test('no detecta si la varianza de montos es muy errática (> 25%)', () {
      final transactions = [
        Transaction(
          id: 'tx-1',
          amount: 50,
          currency: 'PEN',
          merchant: 'Tienda X',
          occurredAt: DateTime(2026, 1, 10),
          category: const Category(id: 'other', name: 'Otros', emoji: '💸'),
          source: TransactionSource.manual,
          scope: TransactionScope.personal,
        ),
        Transaction(
          id: 'tx-2',
          amount: 300,
          currency: 'PEN',
          merchant: 'Tienda X',
          occurredAt: DateTime(2026, 2, 10),
          category: const Category(id: 'other', name: 'Otros', emoji: '💸'),
          source: TransactionSource.manual,
          scope: TransactionScope.personal,
        ),
      ];

      final result = detector(transactions);
      expect(result, isEmpty);
    });
  });

  group('CalculateMonthlyProjection', () {
    const calculator = CalculateMonthlyProjection();

    test('calcula burn rate y proyección a mitad de mes', () {
      final currentExpenses = [
        Transaction(
          id: 'tx-1',
          amount: 300,
          currency: 'PEN',
          merchant: 'Supermercado',
          occurredAt: DateTime(2026, 4, 5),
          category: const Category(id: 'groceries', name: 'Supermercado', emoji: '🛒'),
          source: TransactionSource.manual,
          scope: TransactionScope.personal,
        ),
        Transaction(
          id: 'tx-2',
          amount: 300,
          currency: 'PEN',
          merchant: 'Restaurante',
          occurredAt: DateTime(2026, 4, 10),
          category: const Category(id: 'food', name: 'Comida', emoji: '🍔'),
          source: TransactionSource.manual,
          scope: TransactionScope.personal,
        ),
      ];

      final recurring = [
        RecurringExpense(
          merchant: 'Internet',
          averageAmount: 100,
          currency: 'PEN',
          category: const Category(id: 'services', name: 'Servicios', emoji: '💡'),
          frequency: RecurringFrequency.monthly,
          lastOccurredAt: DateTime(2026, 3, 20),
          estimatedNextDate: DateTime(2026, 4, 20),
          occurrencesCount: 3,
        ),
      ];

      final projection = calculator(
        currentMonthTransactions: currentExpenses,
        recurringExpenses: recurring,
        targetMonth: DateTime(2026, 4),
        now: DateTime(2026, 4, 15),
      );

      expect(projection.currentTotal, equals(600.0));
      expect(projection.daysElapsed, equals(15));
      expect(projection.daysInMonth, equals(30));
      expect(projection.dailyBurnRate, equals(40.0)); // 600 / 15
      expect(projection.pendingRecurringTotal, equals(100.0));
      expect(projection.projectedTotal, greaterThan(600.0));
    });
  });
}
