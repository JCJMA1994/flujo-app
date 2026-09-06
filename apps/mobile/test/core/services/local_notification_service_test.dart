import 'package:flujo/core/services/local_notification_service.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late LocalNotificationService service;

  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(),
    );
    registerFallbackValue(
      const NotificationDetails(),
    );
  });

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    when(
      () => mockPlugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse:
            any(named: 'onDidReceiveNotificationResponse'),
        onDidReceiveBackgroundNotificationResponse:
            any(named: 'onDidReceiveBackgroundNotificationResponse'),
      ),
    ).thenAnswer((_) async => true);

    when(() => mockPlugin.getNotificationAppLaunchDetails())
        .thenAnswer((_) async => null);

    when(
      () => mockPlugin.show(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        notificationDetails: any(named: 'notificationDetails'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});

    service = LocalNotificationService(plugin: mockPlugin);
  });

  test(
      'showTransactionNotification muestra notificación para gastos confirmados',
      () async {
    final expenseTx = Transaction(
      id: 'tx-exp-1',
      amount: 45.50,
      currency: 'PEN',
      merchant: 'Supermercado Metro',
      occurredAt: DateTime(2026, 9),
      category:
          const Category(id: 'groceries', name: 'Alimentación', emoji: '🛒'),
      source: TransactionSource.bankNotification,
      scope: TransactionScope.personal,
      rawText: 'Compra Metro',
    );

    await service.showTransactionNotification(expenseTx);

    verify(
      () => mockPlugin.show(
        id: any(named: 'id'),
        title: '💸 Gasto registrado: S/ 45.50',
        body: 'Supermercado Metro · Alimentación 🛒',
        notificationDetails: any(named: 'notificationDetails'),
        payload: 'tx-exp-1',
      ),
    ).called(1);
  });

  test(
      'showTransactionNotification muestra notificación interactiva para gastos pendientes',
      () async {
    final pendingExpenseTx = Transaction(
      id: 'tx-exp-pending',
      amount: 45.50,
      currency: 'PEN',
      merchant: 'Supermercado Metro',
      occurredAt: DateTime(2026, 9),
      category:
          const Category(id: 'groceries', name: 'Alimentación', emoji: '🛒'),
      source: TransactionSource.bankNotification,
      scope: TransactionScope.personal,
      reviewed: false,
      rawText: 'Compra Metro',
    );

    await service.showTransactionNotification(pendingExpenseTx);

    verify(
      () => mockPlugin.show(
        id: any(named: 'id'),
        title: '💸 ¿Confirmar gasto: S/ 45.50?',
        body: 'Supermercado Metro · Alimentación 🛒 (IA)',
        notificationDetails: any(named: 'notificationDetails'),
        payload: 'tx-exp-pending',
      ),
    ).called(1);
  });

  test(
      'showTransactionNotification muestra notificación para ingresos confirmados',
      () async {
    final incomeTx = Transaction(
      id: 'tx-inc-1',
      amount: 1200,
      currency: 'USD',
      merchant: 'Cliente ABC',
      occurredAt: DateTime(2026, 9),
      category: const Category(id: 'salary', name: 'Salario', emoji: '💼'),
      source: TransactionSource.bankNotification,
      scope: TransactionScope.business,
      type: TransactionType.income,
      rawText: 'Transferencia recibida',
    );

    await service.showTransactionNotification(incomeTx);

    verify(
      () => mockPlugin.show(
        id: any(named: 'id'),
        title: r'💰 Ingreso registrado: $ 1200.00',
        body: 'Cliente ABC · Salario 💼',
        notificationDetails: any(named: 'notificationDetails'),
        payload: 'tx-inc-1',
      ),
    ).called(1);
  });
}
