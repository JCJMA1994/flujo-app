import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _remoteDataSource.login(
        email: email,
        password: password,
      );
      await _localDataSource.saveSession(
        token: session.token,
        user: session.user,
      );
      return Success(session.user.toEntity());
    } on Failure catch (failure) {
      return FailureResult(failure);
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final session = await _remoteDataSource.register(
        email: email,
        password: password,
        name: name,
      );
      await _localDataSource.saveSession(
        token: session.token,
        user: session.user,
      );
      return Success(session.user.toEntity());
    } on Failure catch (failure) {
      return FailureResult(failure);
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      await _localDataSource.clearSession();
      return const Success(null);
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<User?>> getCurrentSession() async {
    try {
      final token = await _localDataSource.getToken();
      if (token == null) {
        return const Success(null);
      }

      // Si hay sesión local, intentamos validar con el servidor
      try {
        final remoteUser = await _remoteDataSource.getCurrentUser();
        await _localDataSource.saveSession(token: token, user: remoteUser);
        return Success(remoteUser.toEntity());
      } catch (_) {
        // Fallback offline: usar datos del usuario en almacenamiento local
        final localUser = await _localDataSource.getUser();
        return Success(localUser?.toEntity());
      }
    } catch (e) {
      return FailureResult(CacheFailure(e.toString()));
    }
  }
}
