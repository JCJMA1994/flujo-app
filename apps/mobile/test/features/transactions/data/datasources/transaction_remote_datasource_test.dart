import 'package:dio/dio.dart';
import 'package:flujo/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:flujo/features/transactions/data/models/transaction_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late TransactionRemoteDataSourceImpl remoteDataSource;

  final model = TransactionModel(
    id: 'tx-1',
    amount: 50,
    currency: 'PEN',
    merchant: 'Supermercado',
    occurredAt: DateTime(2026, 9),
    categoryId: 'groceries',
    categoryName: 'Supermercado',
    categoryEmoji: '🛒',
    source: 'manual',
    scope: 'personal',
    confidence: 1,
    reviewed: true,
  );

  setUp(() {
    dio = MockDio();
    remoteDataSource = TransactionRemoteDataSourceImpl(dio);
  });

  group('TransactionRemoteDataSourceImpl', () {
    group('push', () {
      test('devuelve lista vacía sin hacer petición si models está vacío',
          () async {
        final result = await remoteDataSource.push([]);

        expect(result, isEmpty);
        verifyNever(
          () => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ),
        );
      });

      test('envía transacciones al backend y retorna ids confirmados',
          () async {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/v1/transactions/sync',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/v1/transactions/sync'),
            statusCode: 200,
            data: {
              'acknowledged': ['tx-1'],
              'conflicts': <dynamic>[],
            },
          ),
        );

        final result = await remoteDataSource.push([model]);

        expect(result, ['tx-1']);
        verify(
          () => dio.post<Map<String, dynamic>>(
            '/v1/transactions/sync',
            data: {
              'transactions': [model.toJson()],
            },
          ),
        ).called(1);
      });
    });

    group('pullSince', () {
      test('obtiene transacciones remotas a partir del cursor temporal',
          () async {
        final cursor = DateTime(2026, 9);

        when(
          () => dio.get<dynamic>(
            '/v1/transactions',
            queryParameters: any(named: 'queryParameters'),
          ),
        ).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/v1/transactions'),
            statusCode: 200,
            data: {
              'transactions': [model.toJson()],
            },
          ),
        );

        final result = await remoteDataSource.pullSince(cursor);

        expect(result.length, 1);
        expect(result.first.id, 'tx-1');
        expect(result.first.merchant, 'Supermercado');
        verify(
          () => dio.get<dynamic>(
            '/v1/transactions',
            queryParameters: {'since': cursor.toIso8601String()},
          ),
        ).called(1);
      });
    });
  });
}
