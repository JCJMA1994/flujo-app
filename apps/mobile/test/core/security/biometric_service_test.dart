import 'package:flujo/core/security/biometric_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockLocalAuthentication mockAuth;
  late MockFlutterSecureStorage mockStorage;
  late BiometricService service;

  setUp(() {
    mockAuth = MockLocalAuthentication();
    mockStorage = MockFlutterSecureStorage();
    service = BiometricService(
      auth: mockAuth,
      storage: mockStorage,
    );
  });

  group('BiometricService', () {
    test('isBiometricsAvailable retorna true si el dispositivo soporta y puede chequear', () async {
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => true);

      final result = await service.isBiometricsAvailable();

      expect(result, isTrue);
    });

    test('isBiometricLockEnabled lee correctamente de secure storage', () async {
      when(() => mockStorage.read(key: 'biometric_lock_enabled'))
          .thenAnswer((_) async => 'true');

      final result = await service.isBiometricLockEnabled();

      expect(result, isTrue);
    });

    test('setBiometricLockEnabled escribe en secure storage', () async {
      when(() => mockStorage.write(key: 'biometric_lock_enabled', value: 'true'))
          .thenAnswer((_) async {});

      await service.setBiometricLockEnabled(enabled: true);

      verify(() => mockStorage.write(key: 'biometric_lock_enabled', value: 'true')).called(1);
    });

    test('authenticate invoca LocalAuthentication con las opciones correctas', () async {
      when(() => mockAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(
        () => mockAuth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
          persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
        ),
      ).thenAnswer((_) async => true);

      final result = await service.authenticate(reason: 'Test reason');

      expect(result, isTrue);
      verify(
        () => mockAuth.authenticate(
          localizedReason: 'Test reason',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        ),
      ).called(1);
    });
  });
}
