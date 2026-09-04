import 'package:dio/dio.dart';
import 'package:flujo/core/network/dio_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late MockErrorInterceptorHandler mockErrorHandler;
  late MockRequestInterceptorHandler mockRequestHandler;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    mockErrorHandler = MockErrorInterceptorHandler();
    mockRequestHandler = MockRequestInterceptorHandler();
  });

  group('DioClient', () {
    test('agrega header Authorization cuando existe token guardado', () async {
      when(() => mockStorage.read(key: 'access_token'))
          .thenAnswer((_) async => 'fake-jwt-token');

      final client = DioClient(
        baseUrl: 'https://api.flujo.com',
        storage: mockStorage,
      );

      final requestOptions = RequestOptions(path: '/v1/transactions');

      client.dio.interceptors
          .firstWhere((i) => i.runtimeType.toString() == '_AuthInterceptor')
          .onRequest(requestOptions, mockRequestHandler);

      await pumpEventQueue();

      expect(requestOptions.headers['Authorization'], 'Bearer fake-jwt-token');
      verify(() => mockRequestHandler.next(requestOptions)).called(1);
    });

    test('elimina token y ejecuta onUnauthorized ante error 401 en ruta protegida',
        () async {
      when(() => mockStorage.delete(key: 'access_token'))
          .thenAnswer((_) async {});

      var unauthorizedCalled = false;
      final client = DioClient(
        baseUrl: 'https://api.flujo.com',
        storage: mockStorage,
        onUnauthorized: () => unauthorizedCalled = true,
      );

      final authInterceptor = client.dio.interceptors
          .firstWhere((i) => i.runtimeType.toString() == '_AuthInterceptor');

      final dioError = DioException(
        requestOptions: RequestOptions(path: '/v1/transactions'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/transactions'),
          statusCode: 401,
        ),
      );

      authInterceptor.onError(dioError, mockErrorHandler);

      await pumpEventQueue();

      verify(() => mockStorage.delete(key: 'access_token')).called(1);
      verify(() => mockErrorHandler.next(dioError)).called(1);
      expect(unauthorizedCalled, isTrue);
    });

    test('no ejecuta onUnauthorized si el 401 proviene de /v1/auth/login', () async {
      var unauthorizedCalled = false;
      final client = DioClient(
        baseUrl: 'https://api.flujo.com',
        storage: mockStorage,
        onUnauthorized: () => unauthorizedCalled = true,
      );

      final authInterceptor = client.dio.interceptors
          .firstWhere((i) => i.runtimeType.toString() == '_AuthInterceptor');

      final dioError = DioException(
        requestOptions: RequestOptions(path: '/v1/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/auth/login'),
          statusCode: 401,
        ),
      );

      authInterceptor.onError(dioError, mockErrorHandler);

      await pumpEventQueue();

      verifyNever(() => mockStorage.delete(key: 'access_token'));
      verify(() => mockErrorHandler.next(dioError)).called(1);
      expect(unauthorizedCalled, isFalse);
    });
  });
}
