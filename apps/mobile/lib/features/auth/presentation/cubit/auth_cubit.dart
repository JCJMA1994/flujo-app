import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/auth_usecases.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required GetAuthSessionUseCase getAuthSessionUseCase,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _logoutUseCase = logoutUseCase,
        _getAuthSessionUseCase = getAuthSessionUseCase,
        super(const AuthState.initial());

  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetAuthSessionUseCase _getAuthSessionUseCase;

  Future<void> checkSession() async {
    final result = await _getAuthSessionUseCase();
    result.fold(
      onSuccess: (user) {
        if (user != null) {
          emit(state.copyWith(status: AuthStatus.authenticated, user: user));
        } else {
          emit(const AuthState(status: AuthStatus.unauthenticated));
        }
      },
      onFailure: (_) {
        emit(const AuthState(status: AuthStatus.unauthenticated));
      },
    );
  }

  Future<void> login({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _loginUseCase(email: email, password: password);
    result.fold(
      onSuccess: (user) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      },
      onFailure: (failure) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _registerUseCase(
      email: email,
      password: password,
      name: name,
    );
    result.fold(
      onSuccess: (user) {
        emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      },
      onFailure: (failure) {
        emit(
          state.copyWith(
            status: AuthStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }

  Future<void> logout() async {
    emit(state.copyWith(status: AuthStatus.loading));
    await _logoutUseCase();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void sessionExpired() {
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Tu sesión ha expirado. Por favor, ingresa de nuevo.',
      ),
    );
  }
}
