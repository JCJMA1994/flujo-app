import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveSession({
    required String token,
    required UserModel user,
  });

  Future<String?> getToken();

  Future<UserModel?> getUser();

  Future<void> clearSession();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({required FlutterSecureStorage storage})
      : _storage = storage;

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'access_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _userNameKey = 'user_name';

  @override
  Future<void> saveSession({
    required String token,
    required UserModel user,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: user.id);
    await _storage.write(key: _userEmailKey, value: user.email);
    await _storage.write(key: _userNameKey, value: user.name);
  }

  @override
  Future<String?> getToken() => _storage.read(key: _tokenKey);

  @override
  Future<UserModel?> getUser() async {
    final id = await _storage.read(key: _userIdKey);
    final email = await _storage.read(key: _userEmailKey);
    final name = await _storage.read(key: _userNameKey);

    if (id == null || email == null || name == null) {
      return null;
    }

    return UserModel(id: id, email: email, name: name);
  }

  @override
  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _userNameKey);
  }
}
