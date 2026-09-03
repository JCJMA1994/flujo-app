import '../../../../core/utils/result.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Result<User>> login({
    required String email,
    required String password,
  });

  Future<Result<User>> register({
    required String email,
    required String password,
    required String name,
  });

  Future<Result<void>> logout();

  Future<Result<User?>> getCurrentSession();
}
