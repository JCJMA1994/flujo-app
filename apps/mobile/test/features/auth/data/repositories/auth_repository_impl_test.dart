import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:flujo/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:flujo/features/auth/data/models/user_model.dart';
import 'package:flujo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flujo/features/auth/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockAuthLocalDataSource extends Mock implements AuthLocalDataSource {}

void main() {
  late MockAuthRemoteDataSource mockRemoteDataSource;
  late MockAuthLocalDataSource mockLocalDataSource;
  late AuthRepositoryImpl repository;

  const tUserModel = UserModel(
    id: 'user-001',
    email: 'test@flujo.com',
    name: 'Usuario Test',
  );

  setUp(() {
    mockRemoteDataSource = MockAuthRemoteDataSource();
    mockLocalDataSource = MockAuthLocalDataSource();
    repository = AuthRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
    );
  });

  group('AuthRepositoryImpl', () {
    test('login guarda sesión localmente y retorna entidad de usuario ante éxito', () async {
      when(
        () => mockRemoteDataSource.login(
          email: 'test@flujo.com',
          password: 'password123',
        ),
      ).thenAnswer(
        (_) async => const AuthSessionData(
          token: 'token-xyz',
          user: tUserModel,
        ),
      );

      when(
        () => mockLocalDataSource.saveSession(
          token: 'token-xyz',
          user: tUserModel,
        ),
      ).thenAnswer((_) async {});

      final result = await repository.login(
        email: 'test@flujo.com',
        password: 'password123',
      );

      expect(result, isA<Success<User>>());
      final user = (result as Success<User>).value;
      expect(user.id, equals('user-001'));
      expect(user.email, equals('test@flujo.com'));
      verify(() => mockLocalDataSource.saveSession(token: 'token-xyz', user: tUserModel)).called(1);
    });

    test('register guarda sesión y retorna entidad de usuario', () async {
      when(
        () => mockRemoteDataSource.register(
          email: 'test@flujo.com',
          password: 'password123',
          name: 'Usuario Test',
        ),
      ).thenAnswer(
        (_) async => const AuthSessionData(
          token: 'token-xyz',
          user: tUserModel,
        ),
      );

      when(
        () => mockLocalDataSource.saveSession(
          token: 'token-xyz',
          user: tUserModel,
        ),
      ).thenAnswer((_) async {});

      final result = await repository.register(
        email: 'test@flujo.com',
        password: 'password123',
        name: 'Usuario Test',
      );

      expect(result, isA<Success<User>>());
      final user = (result as Success<User>).value;
      expect(user.email, equals('test@flujo.com'));
    });

    test('logout limpia el almacenamiento local', () async {
      when(() => mockLocalDataSource.clearSession()).thenAnswer((_) async {});

      final result = await repository.logout();

      expect(result, isA<Success<void>>());
      verify(() => mockLocalDataSource.clearSession()).called(1);
    });

    test('getCurrentSession retorna null cuando no hay token guardado', () async {
      when(() => mockLocalDataSource.getToken()).thenAnswer((_) async => null);

      final result = await repository.getCurrentSession();

      expect(result, isA<Success<User?>>());
      expect((result as Success<User?>).value, isNull);
    });
  });
}
