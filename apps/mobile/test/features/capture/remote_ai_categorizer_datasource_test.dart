import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/capture/data/datasources/ai_categorizer_datasource.dart';
import 'package:flujo/features/capture/domain/entities/parsed_expense.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio mockDio;
  late RemoteAiCategorizerDataSource dataSource;

  setUp(() {
    mockDio = MockDio();
    dataSource = RemoteAiCategorizerDataSource(mockDio);
  });

  group('interpret', () {
    test('parses income transaction type correctly from backend', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/v1/capture/interpret',
          data: {'raw_text': '¡Te yapearon! Carlos te envió S/ 50.00'},
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/capture/interpret'),
          statusCode: 200,
          data: {
            'amount': 50.0,
            'currency': 'PEN',
            'merchant': 'Carlos',
            'occurred_at': '2026-09-04T10:00:00-05:00',
            'category_id': 'other_income',
            'bank_id': 'yape',
            'confidence': 0.95,
            'type': 'income',
          },
        ),
      );

      final result =
          await dataSource.interpret('¡Te yapearon! Carlos te envió S/ 50.00');

      expect(result, isA<Success<ParsedExpense>>());
      result.fold(
        onFailure: (f) => fail('Should succeed'),
        onSuccess: (expense) {
          expect(expense.amount, 50.0);
          expect(expense.merchant, 'Carlos');
          expect(expense.type, TransactionType.income);
          expect(expense.currency, 'PEN');
          expect(expense.bankId, 'yape');
        },
      );
    });

    test('defaults to expense when type is expense or missing', () async {
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/v1/capture/interpret',
          data: {'raw_text': 'Yapeaste S/ 15.00 a Bodega Don Pepe'},
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/capture/interpret'),
          statusCode: 200,
          data: {
            'amount': 15.0,
            'currency': 'PEN',
            'merchant': 'Bodega Don Pepe',
            'category_id': 'groceries',
            'bank_id': 'yape',
            'confidence': 0.98,
            'type': 'expense',
          },
        ),
      );

      final result =
          await dataSource.interpret('Yapeaste S/ 15.00 a Bodega Don Pepe');

      expect(result, isA<Success<ParsedExpense>>());
      result.fold(
        onFailure: (f) => fail('Should succeed'),
        onSuccess: (expense) {
          expect(expense.amount, 15.0);
          expect(expense.type, TransactionType.expense);
        },
      );
    });
  });

  group('interpretImage', () {
    test('parses income voucher from backend correctly', () async {
      final imageBytes = [1, 2, 3, 4];
      when(
        () => mockDio.post<Map<String, dynamic>>(
          '/v1/capture/interpret-image',
          data: {
            'image_base64': base64Encode(imageBytes),
            'mime_type': 'image/jpeg',
          },
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/v1/capture/interpret-image'),
          statusCode: 200,
          data: {
            'amount': 120.0,
            'currency': 'PEN',
            'merchant': 'Juan Pérez',
            'occurred_at': '2026-09-04T10:15:00-05:00',
            'category_id': 'other_income',
            'bank_id': 'plin',
            'confidence': 0.92,
            'type': 'income',
          },
        ),
      );

      final result = await dataSource.interpretImage(imageBytes: imageBytes);

      expect(result, isA<Success<ParsedExpense>>());
      result.fold(
        onFailure: (f) => fail('Should succeed'),
        onSuccess: (expense) {
          expect(expense.amount, 120.0);
          expect(expense.merchant, 'Juan Pérez');
          expect(expense.type, TransactionType.income);
          expect(expense.bankId, 'plin');
        },
      );
    });
  });
}
