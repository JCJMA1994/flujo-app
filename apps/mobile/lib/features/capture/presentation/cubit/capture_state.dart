part of 'capture_cubit.dart';

enum CapturePermission { unknown, granted, denied, unsupported }

enum CaptureHealth {
  ready,
  notificationPermissionMissing,
  listenerDisconnected,
  batteryRestricted,
  manufacturerConfigurationRequired,
  processingError,
}

final class CaptureState extends Equatable {
  const CaptureState({
    this.permission = CapturePermission.unknown,
    this.health = CaptureHealth.notificationPermissionMissing,
    this.isListenerConnected = false,
    this.isBatteryRestricted = false,
    this.isAggressiveOem = false,
    this.diagnostics = const {},
    this.rules = const [],
    this.lastCaptured,
    this.capturedCount = 0,
    this.unrecognizedCount = 0,
    this.failure,
  });

  final CapturePermission permission;
  final CaptureHealth health;
  final bool isListenerConnected;
  final bool isBatteryRestricted;
  final bool isAggressiveOem;
  final Map<String, dynamic> diagnostics;
  final List<UserRule> rules;
  final Transaction? lastCaptured;
  final int capturedCount;

  /// Notificaciones que ni los parsers ni la IA supieron leer. Es la métrica
  /// que dice qué banco falta soportar.
  final int unrecognizedCount;

  final Failure? failure;

  bool get isActive => health == CaptureHealth.ready;

  CaptureState copyWith({
    CapturePermission? permission,
    CaptureHealth? health,
    bool? isListenerConnected,
    bool? isBatteryRestricted,
    bool? isAggressiveOem,
    Map<String, dynamic>? diagnostics,
    List<UserRule>? rules,
    Transaction? lastCaptured,
    int? capturedCount,
    int? unrecognizedCount,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CaptureState(
      permission: permission ?? this.permission,
      health: health ?? this.health,
      isListenerConnected: isListenerConnected ?? this.isListenerConnected,
      isBatteryRestricted: isBatteryRestricted ?? this.isBatteryRestricted,
      isAggressiveOem: isAggressiveOem ?? this.isAggressiveOem,
      diagnostics: diagnostics ?? this.diagnostics,
      rules: rules ?? this.rules,
      lastCaptured: lastCaptured ?? this.lastCaptured,
      capturedCount: capturedCount ?? this.capturedCount,
      unrecognizedCount: unrecognizedCount ?? this.unrecognizedCount,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        permission,
        health,
        isListenerConnected,
        isBatteryRestricted,
        isAggressiveOem,
        diagnostics,
        rules,
        lastCaptured,
        capturedCount,
        unrecognizedCount,
        failure,
      ];
}
