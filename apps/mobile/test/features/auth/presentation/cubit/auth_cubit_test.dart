import 'package:bloc_test/bloc_test.dart';
import 'package:flujo/core/error/failures.dart';
import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/auth/domain/entities/user.dart';
import 'package:flujo/features/auth/domain/usecases/auth_usecases.dart';
import 'package:flujo/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flujo/features/auth/presentation/cubit/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginUseCase extends Mock implements LoginUseCase {}

class MockRegisterUseCase extends Mock implements RegisterUseCase {}

class MockLogoutUseCase extends Mock implements LogoutUseCase {}

class MockGetAuthSessionUseCase extends Mock implements GetAuthSessionUseCase {}

void main() {
  late MockLoginUseCase mockLoginUseCase;
  late MockRegisterUseCase mockRegisterUseCase;
  late MockLogoutUseCase mockLogoutUseCase;
  late MockGetAuthSessionUseCase mockGetAuthSessionUseCase;
  late AuthCubit authCubit;

  const tUser = User(
    id: 'user-123',
    email: 'dev@flujo.com',
    name: 'Juan Perez',
  );

  setUp(() {
    mockLoginUseCase = MockLoginUseCase();
    mockRegisterUseCase = MockRegisterUseCase();
    mockLogoutUseCase = MockLogoutUseCase();
    mockGetAuthSessionUseCase = MockGetAuthSessionUseCase();

    authCubit = AuthCubit(
      loginUseCase: mockLoginUseCase,
      registerUseCase: mockRegisterUseCase,
      logoutUseCase: mockLogoutUseCase,
      getAuthSessionUseCase: mockGetAuthSessionUseCase,
    );
  });

  tearDown(() {
    authCubit.close();
  });

  group('AuthCubit', () {
    test('estado inicial es AuthStatus.initial', () {
      expect(authCubit.state.status, equals(AuthStatus.initial));
      expect(authCubit.state.user, isNull);
    });

    blocTest<AuthCubit, AuthState>(
      'checkSession emite authenticated cuando hay usuario en sesión',
      build: () {
        when(() => mockGetAuthSessionUseCase())
            .thenAnswer((_) async => const Success(tUser));
        return authCubit;
      },
      act: (cubit) => cubit.checkSession(),
      expect: () => [
        const AuthState(status: AuthStatus.authenticated, user: tUser),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'checkSession emite unauthenticated cuando no hay sesión activa',
      build: () {
        when(() => mockGetAuthSessionUseCase())
            .thenAnswer((_) async => const Success(null));
        return authCubit;
      },
      act: (cubit) => cubit.checkSession(),
      expect: () => [
        const AuthState(status: AuthStatus.unauthenticated),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'login emite loading y luego authenticated ante éxito',
      build: () {
        when(
          () => mockLoginUseCase(
            email: 'dev@flujo.com',
            password: 'password123',
          ),
        ).thenAnswer((_) async => const Success(tUser));
        return authCubit;
      },
      act: (cubit) => cubit.login(
        email: 'dev@flujo.com',
        password: 'password123',
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.authenticated, user: tUser),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'login emite loading y luego error ante credenciales incorrectas',
      build: () {
        when(
          () => mockLoginUseCase(
            email: 'dev@flujo.com',
            password: 'wrong',
          ),
        ).thenAnswer(
          (_) async =>
              const FailureResult(AuthFailure('Credenciales incorrectas')),
        );
        return authCubit;
      },
      act: (cubit) => cubit.login(
        email: 'dev@flujo.com',
        password: 'wrong',
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Credenciales incorrectas',
        ),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'register emite loading y luego authenticated ante registro exitoso',
      build: () {
        when(
          () => mockRegisterUseCase(
            email: 'nuevo@flujo.com',
            password: 'password123',
            name: 'Nuevo Usuario',
          ),
        ).thenAnswer((_) async => const Success(tUser));
        return authCubit;
      },
      act: (cubit) => cubit.register(
        email: 'nuevo@flujo.com',
        password: 'password123',
        name: 'Nuevo Usuario',
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.authenticated, user: tUser),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'logout emite loading y luego unauthenticated',
      build: () {
        when(() => mockLogoutUseCase())
            .thenAnswer((_) async => const Success(null));
        return authCubit;
      },
      act: (cubit) => cubit.logout(),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.unauthenticated),
      ],
    );

    blocTest<AuthCubit, AuthState>(
      'sessionExpired emite unauthenticated con mensaje de expiración',
      build: () => authCubit,
      act: (cubit) => cubit.sessionExpired(),
      expect: () => [
        const AuthState(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Tu sesión ha expirado. Por favor, ingresa de nuevo.',
        ),
      ],
    );
  });
}
