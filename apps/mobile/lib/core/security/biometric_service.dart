import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Servicio para gestión de autenticación biométrica (Huella digital / FaceID).
class BiometricService {
  BiometricService({
    LocalAuthentication? auth,
    FlutterSecureStorage? storage,
  })  : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _prefKey = 'biometric_lock_enabled';

  /// Verifica si el dispositivo soporta biometría y si tiene biometría configurada.
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Indica si el usuario activó la biometría en sus ajustes de Flujo.
  Future<bool> isBiometricLockEnabled() async {
    final value = await _storage.read(key: _prefKey);
    return value == 'true';
  }

  /// Guarda la preferencia del usuario.
  Future<void> setBiometricLockEnabled({required bool enabled}) async {
    await _storage.write(key: _prefKey, value: enabled ? 'true' : 'false');
  }

  /// Dispara el diálogo nativo de autenticación biométrica.
  Future<bool> authenticate({
    String reason = 'Verifica tu identidad para acceder a Flujo',
  }) async {
    try {
      final available = await isBiometricsAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
