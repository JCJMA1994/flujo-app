import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../models/user_model.dart';

class AuthSessionData {
  const AuthSessionData({
    required this.token,
    required this.user,
  });

  final String token;
  final UserModel user;
}

abstract class AuthRemoteDataSource {
  Future<AuthSessionData> login({
    required String email,
    required String password,
  });

  Future<AuthSessionData> register({
    required String email,
    required String password,
    required String name,
  });

  Future<UserModel> getCurrentUser();

  Future<void> logout();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  @override
  Future<AuthSessionData> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data!;
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      return AuthSessionData(token: token, user: user);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthFailure('Credenciales incorrectas');
      }
      throw ServerFailure(
        e.response?.data is Map
            ? (e.response!.data as Map)['error']?.toString() ??
                e.message ??
                'Error de autenticación'
            : e.message ?? 'Error del servidor',
      );
    }
  }

  @override
  Future<AuthSessionData> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/register',
        data: {
          'email': email,
          'password': password,
          'name': name,
        },
      );

      final data = response.data!;
      final token = data['token'] as String;
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);

      return AuthSessionData(token: token, user: user);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw const AuthFailure('El correo electrónico ya está registrado');
      }
      throw ServerFailure(
        e.response?.data is Map
            ? (e.response!.data as Map)['error']?.toString() ??
                e.message ??
                'Error al registrar usuario'
            : e.message ?? 'Error del servidor',
      );
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/auth/me');
      return UserModel.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const AuthFailure('Sesión expirada o no autorizada');
      }
      throw ServerFailure(e.message ?? 'Error consultando usuario actual');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<void>('/v1/auth/logout');
    } catch (_) {
      // Si falla la red, permitimos que el logout local proceda limpiamente
    }
  }
}
