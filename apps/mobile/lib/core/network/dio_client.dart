import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuración del cliente HTTP. Los tokens van en `flutter_secure_storage`
/// (Keychain en iOS, EncryptedSharedPreferences en Android), nunca en
/// SharedPreferences plano ni en la base de datos.
class DioClient {
  DioClient({
    required String baseUrl,
    required FlutterSecureStorage storage,
    this.onUnauthorized,
    bool enableLogging = false,
  }) : _storage = storage {
    if (kReleaseMode && baseUrl.startsWith('http://')) {
      throw ArgumentError(
        'Solo conexiones seguras HTTPS están permitidas en modo producción.',
      );
    }

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(_storage, onUnauthorized: onUnauthorized),
      _RetryInterceptor(dio),
      if (enableLogging)
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          // Nunca loguees el header de autorización.
          logPrint: (o) => debugPrint(_redact(o.toString())),
        ),
    ]);
  }

  late final Dio dio;
  final FlutterSecureStorage _storage;
  final VoidCallback? onUnauthorized;

  static String _redact(String input) => input.replaceAll(
        RegExp(r'(Bearer\s+)[A-Za-z0-9._-]+'),
        r'$1<redacted>',
      );
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage, {this.onUnauthorized});

  final FlutterSecureStorage _storage;
  final VoidCallback? onUnauthorized;
  static const _tokenKey = 'access_token';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      final path = err.requestOptions.path;
      // No disparar auto-logout en login o register (credenciales incorrectas normales)
      final isAuthEndpoint = path.contains('/v1/auth/login') ||
          path.contains('/v1/auth/register');
      if (!isAuthEndpoint) {
        await _storage.delete(key: _tokenKey);
        onUnauthorized?.call();
      }
    }
    handler.next(err);
  }
}

/// Reintenta solo errores transitorios de red. Nunca reintenta un 4xx:
/// si el servidor dijo que la petición está mal, repetirla no la arregla.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const int _maxAttempts = 3;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra['attempt'] as int? ?? 0) + 1;

    if (!_isRetryable(err) || attempt >= _maxAttempts) {
      return handler.next(err);
    }

    // Backoff exponencial: 400ms, 800ms, 1600ms.
    await Future<void>.delayed(Duration(milliseconds: 200 * (1 << attempt)));

    try {
      final response = await _dio.fetch<dynamic>(
        err.requestOptions..extra['attempt'] = attempt,
      );
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _isRetryable(DioException err) {
    if (err.error is SocketException) return true;
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError =>
        true,
      DioExceptionType.badResponse => (err.response?.statusCode ?? 0) >= 500,
      _ => false,
    };
  }
}
