import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User>> call({
    required String email,
    required String password,
  }) {
    if (email.trim().isEmpty || !email.contains('@')) {
      return Future.value(
        const FailureResult(ValidationFailure('Correo electrónico no válido')),
      );
    }
    if (password.length < 6) {
      return Future.value(
        const FailureResult(
          ValidationFailure('La contraseña debe tener al menos 6 caracteres'),
        ),
      );
    }
    return _repository.login(email: email.trim(), password: password);
  }
}

class RegisterUseCase {
  const RegisterUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User>> call({
    required String email,
    required String password,
    required String name,
  }) {
    if (name.trim().isEmpty) {
      return Future.value(
        const FailureResult(ValidationFailure('El nombre es obligatorio')),
      );
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      return Future.value(
        const FailureResult(ValidationFailure('Correo electrónico no válido')),
      );
    }
    if (password.length < 6) {
      return Future.value(
        const FailureResult(
          ValidationFailure('La contraseña debe tener al menos 6 caracteres'),
        ),
      );
    }
    return _repository.register(
      email: email.trim(),
      password: password,
      name: name.trim(),
    );
  }
}

class LogoutUseCase {
  const LogoutUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.logout();
}

class GetAuthSessionUseCase {
  const GetAuthSessionUseCase(this._repository);
  final AuthRepository _repository;

  Future<Result<User?>> call() => _repository.getCurrentSession();
}
