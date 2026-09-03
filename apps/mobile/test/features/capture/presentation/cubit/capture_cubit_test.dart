import 'package:bloc_test/bloc_test.dart';
import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/capture/data/datasources/notification_listener_datasource.dart';
import 'package:flujo/features/capture/data/parsers/expense_parsing_pipeline.dart';
import 'package:flujo/features/capture/domain/entities/parsed_expense.dart';
import 'package:flujo/features/capture/presentation/cubit/capture_cubit.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flujo/features/transactions/domain/usecases/usecases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockNotificationListenerDataSource extends Mock
    implements NotificationListenerDataSource {}

class MockExpenseParsingPipeline extends Mock
    implements ExpenseParsingPipeline {}

class MockAddTransaction extends Mock implements AddTransaction {}

class MockUuid extends Mock implements Uuid {}

void main() {
  late MockNotificationListenerDataSource listener;
  late MockExpenseParsingPipeline pipeline;
  late MockAddTransaction addTransaction;
  late MockUuid uuid;

  final sampleNotification = RawNotification(
    packageName: 'pe.com.bcp.bank.bcp',
    title: 'BCP',
    body: 'Consumo de S/24.50 en Starbucks',
    receivedAt: DateTime(2026, 9),
  );

  final sampleExpense = ParsedExpense(
    amount: 24.50,
    currency: 'PEN',
    merchant: 'Starbucks',
    occurredAt: DateTime(2026, 9),
    confidence: 1,
    rawText: 'Consumo de S/24.50 en Starbucks',
  );

  final sampleTx = Transaction(
    id: 'tx-123',
    amount: 24.50,
    currency: 'PEN',
    merchant: 'Starbucks',
    occurredAt: DateTime(2026, 9),
    category: const Category(id: 'other', name: 'Otros', emoji: '💸'),
    source: TransactionSource.bankNotification,
    scope: TransactionScope.personal,
    rawText: 'Consumo de S/24.50 en Starbucks',
  );

  setUpAll(() {
    registerFallbackValue(sampleNotification);
    registerFallbackValue(sampleTx);
  });

  setUp(() {
    listener = MockNotificationListenerDataSource();
    pipeline = MockExpenseParsingPipeline();
    addTransaction = MockAddTransaction();
    uuid = MockUuid();

    when(() => uuid.v4()).thenReturn('tx-123');
    when(() => listener.stream).thenAnswer((_) => const Stream.empty());
  });

  group('CaptureCubit', () {
    test('estado inicial es CaptureState con permission unknown', () {
      final cubit = CaptureCubit(
        listener: listener,
        pipeline: pipeline,
        addTransaction: addTransaction,
        uuid: uuid,
      );

      expect(cubit.state.permission, CapturePermission.unknown);
      expect(cubit.state.capturedCount, 0);
      expect(cubit.state.unrecognizedCount, 0);
    });

    blocTest<CaptureCubit, CaptureState>(
      'checkPermission emite unsupported si la plataforma no lo soporta',
      setUp: () {
        when(() => listener.isSupported).thenReturn(false);
      },
      build: () => CaptureCubit(
        listener: listener,
        pipeline: pipeline,
        addTransaction: addTransaction,
        uuid: uuid,
      ),
      act: (cubit) => cubit.checkPermission(),
      expect: () => [
        const CaptureState(permission: CapturePermission.unsupported),
      ],
    );

    blocTest<CaptureCubit, CaptureState>(
      'checkPermission emite granted e inicia escucha si tiene permiso',
      setUp: () {
        when(() => listener.isSupported).thenReturn(true);
        when(() => listener.hasPermission()).thenAnswer((_) async => true);
      },
      build: () => CaptureCubit(
        listener: listener,
        pipeline: pipeline,
        addTransaction: addTransaction,
        uuid: uuid,
      ),
      act: (cubit) => cubit.checkPermission(),
      expect: () => [
        const CaptureState(permission: CapturePermission.granted),
      ],
      verify: (_) {
        verify(() => listener.stream).called(1);
      },
    );

    blocTest<CaptureCubit, CaptureState>(
      'procesa notificación exitosamente y registra transacción',
      setUp: () {
        when(() => listener.isSupported).thenReturn(true);
        when(() => listener.stream)
            .thenAnswer((_) => Stream.value(sampleNotification));
        when(
          () => pipeline.process(
            any(),
            rules: any(named: 'rules'),
          ),
        ).thenAnswer((_) async => Success(sampleExpense));
        when(() => addTransaction(any()))
            .thenAnswer((_) async => Success(sampleTx));
      },
      build: () => CaptureCubit(
        listener: listener,
        pipeline: pipeline,
        addTransaction: addTransaction,
        uuid: uuid,
      ),
      act: (cubit) => cubit.startListening(),
      expect: () => [
        CaptureState(
          capturedCount: 1,
          lastCaptured: sampleTx,
        ),
      ],
    );
  });
}
