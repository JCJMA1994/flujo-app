import 'package:dio/dio.dart';
import 'package:flujo/core/error/failures.dart';
import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/capture/data/datasources/gemini_ai_categorizer_datasource.dart';
import 'package:flujo/features/capture/domain/entities/parsed_expense.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockDio mockDio;
  late MockFlutterSecureStorage mockStorage;
  late GeminiAiCategorizerDataSource dataSource;

  setUp(() {
    mockDio = MockDio();
    mockStorage = MockFlutterSecureStorage();
    dataSource = GeminiAiCategorizerDataSource(
      dio: mockDio,
      storage: mockStorage,
    );
  });

  test('retorna ParseFailure si no hay API key configurada', () async {
    when(() => mockStorage.read(key: 'gemini_api_key'))
        .thenAnswer((_) async => null);

    final result = await dataSource.interpret('Confirmación de Pago');

    expect(result, isA<FailureResult<ParsedExpense>>());
    result.fold(
      onFailure: (f) => expect(f, isA<ParseFailure>()),
      onSuccess: (_) => fail('No debía ser éxito'),
    );
  });

  test('interpreta correctamente notificación de Yape personal', () async {
    when(() => mockStorage.read(key: 'gemini_api_key'))
        .thenAnswer((_) async => 'fake_api_key');

    final fakeResponse = Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(),
      data: {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': '''

{
  "amount": 25.50,
  "currency": "PEN",
  "merchant": "Juan Perez",
  "type": "income",
  "scope": "personal",
  "category_id": "other_income",
  "bank_id": "yape",
  "confidence": 0.98
}''',
                }
              ],
            },
          }
        ],
      },
    );

    when(
      () => mockDio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => fakeResponse);

    final result = await dataSource.interpret(
      'Confirmación de Pago Juan Perez te envió un pago por S/ 25.50',
    );

    expect(result, isA<Success<ParsedExpense>>());
    final parsed = (result as Success<ParsedExpense>).value;
    expect(parsed.amount, 25.50);
    expect(parsed.merchant, 'Juan Perez');
    expect(parsed.type, TransactionType.income);
    expect(parsed.scope, TransactionScope.personal);
    expect(parsed.confidence, 0.98);
  });

  test('interpreta correctamente notificación de Yape Empresa / Negocio',
      () async {
    when(() => mockStorage.read(key: 'gemini_api_key'))
        .thenAnswer((_) async => 'fake_api_key');

    final fakeResponse = Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(),
      data: {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': '''

{
  "amount": 150.00,
  "currency": "PEN",
  "merchant": "Bodega Don Pepe SAC",
  "type": "income",
  "scope": "business",
  "category_id": "other_income",
  "bank_id": "yape",
  "confidence": 0.99
}''',
                }
              ],
            },
          }
        ],
      },
    );

    when(
      () => mockDio.post<Map<String, dynamic>>(
        any(),
        data: any(named: 'data'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => fakeResponse);

    final result = await dataSource.interpret(
      'Yape Empresa: Recibiste un cobro de S/ 150.00 en Bodega Don Pepe SAC',
    );

    expect(result, isA<Success<ParsedExpense>>());
    final parsed = (result as Success<ParsedExpense>).value;
    expect(parsed.amount, 150.00);
    expect(parsed.merchant, 'Bodega Don Pepe SAC');
    expect(parsed.scope, TransactionScope.business);
  });
}
