import 'dart:io';

import 'package:flutter/services.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/parsed_expense.dart';

/// Solo escuchamos apps bancarias y billeteras digitales autorizadas.
const kBankPackages = <String>{
  'pe.com.bcp.bank.bcp', // BCP
  'com.bcp.innovacxion.yapeapp', // Yape
  'pe.com.bcp.innovacxion.yapeapp', // Variante Yape
  'com.bcp.yape',
  'pe.interbank.appnew', // Interbank
  'com.bbva.pe.bbvacontigo', // BBVA
  'pe.scotiabank.banking', // Scotiabank
  'com.pichincha.pe', // Pichincha
  'pe.plin.app', // Plin
  'pe.com.banbif.android',
  'pe.com.banbif.banbifmovil',
  'pe.com.cajapiura.pexpe',
  'com.pexpe.app',
  'pe.interbank.tunki',
  'com.tunki.app',
  'pe.com.cajaarequipa.agora',
  'pe.com.cajahuancayo.migente',
  'com.mercadopago.wallet',
  'com.mercadolibre.wallet',
  'pe.com.maximo.app',
  'com.maximo.wallet',
  'ar.com.lemon',
  'com.lemoncash.app',
  'com.grability.rappi',
};

abstract interface class NotificationListenerDataSource {
  Stream<RawNotification> get stream;

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  Future<bool> isListenerConnected();

  Future<Map<String, dynamic>> getDiagnostics();

  Future<void> flushPendingOfflineNotifications();

  Future<void> markNotificationsProcessed(List<int> ids);

  Future<bool> requestIgnoreBatteryOptimizations();

  Future<bool> isIgnoringBatteryOptimizations();

  Future<bool> openAutostartSettings();

  bool get isSupported;
}

/// Android expone `NotificationListenerService`.
class AndroidNotificationListener implements NotificationListenerDataSource {
  AndroidNotificationListener() {
    if (isSupported) _bind();
  }

  final _subject = PublishSubject<RawNotification>();

  @override
  bool get isSupported => Platform.isAndroid;

  @override
  Stream<RawNotification> get stream => _subject
      // Descartamos duplicados en una ventana corta por reemisiones del banco.
      .distinctUnique(
        equals: (a, b) =>
            a.fullText == b.fullText &&
            a.receivedAt.difference(b.receivedAt).abs() <
                const Duration(seconds: 10),
        hashCode: (n) => n.fullText.hashCode,
      )
      .throttleTime(const Duration(milliseconds: 300), trailing: true);

  static const _channel = MethodChannel('com.flujo.app/share');

  void _bind() {
    // 1. Escuchar eventos de notificaciones en tiempo real desde MainActivity / FlujoNotificationListener
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationReceived') {
        final data = call.arguments;
        if (data is Map) {
          _processRawMap(Map<String, dynamic>.from(data));
        }
      } else if (call.method == 'onAppResumed') {
        await flushPendingOfflineNotifications();
      }
    });

    // 2. Recuperar notificaciones que hayan llegado con la app cerrada
    flushPendingOfflineNotifications();
  }

  @override
  Future<void> flushPendingOfflineNotifications() async {
    if (!isSupported) return;
    try {
      final pending = await _channel.invokeMethod<List<dynamic>>(
        'getPendingRawNotifications',
        {'limit': 100},
      );

      if (pending != null && pending.isNotEmpty) {
        final processedIds = <int>[];
        for (final item in pending) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final raw = _createRawFromMap(map);
            if (raw != null) {
              _subject.add(raw);
              if (raw.id != null) {
                processedIds.add(raw.id!);
              }
            }
          }
        }
        if (processedIds.isNotEmpty) {
          await markNotificationsProcessed(processedIds);
        }
      }
    } catch (_) {}
  }

  RawNotification? _createRawFromMap(Map<String, dynamic> data) {
    final package = (data['packageName'] as String? ?? '').toLowerCase();
    final title = data['title'] as String? ?? '';
    final body =
        (data['body'] ?? data['content'] ?? data['text'] ?? '') as String;
    final postTime = data['postTime'] as int? ?? data['timestamp'] as int?;

    if (!_isValidFinancialNotification(package, title, body)) return null;

    return RawNotification(
      id: (data['id'] as num?)?.toInt(),
      notificationKey: data['notificationKey'] as String?,
      notificationHash: data['notificationHash'] as String?,
      packageName: package,
      title: title,
      body: body,
      receivedAt: postTime != null
          ? DateTime.fromMillisecondsSinceEpoch(postTime)
          : DateTime.now(),
    );
  }

  void _processRawMap(Map<String, dynamic> data) {
    final raw = _createRawFromMap(data);
    if (raw != null) {
      _subject.add(raw);
      if (raw.id != null) {
        markNotificationsProcessed([raw.id!]);
      }
    }
  }

  bool _isValidFinancialNotification(
    String package,
    String title,
    String body,
  ) {
    final pkg = package.toLowerCase();
    final isBankPackage = kBankPackages.contains(pkg) ||
        pkg.contains('yape') ||
        pkg.contains('plin') ||
        pkg.contains('bcp') ||
        pkg.contains('bbva') ||
        pkg.contains('interbank') ||
        pkg.contains('scotiabank') ||
        pkg.contains('pichincha');

    return isBankPackage;
  }

  @override
  Future<void> markNotificationsProcessed(List<int> ids) async {
    if (!isSupported || ids.isEmpty) return;
    try {
      await _channel
          .invokeMethod('markRawNotificationsProcessed', {'ids': ids});
    } catch (_) {}
  }

  @override
  Future<bool> isListenerConnected() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('isListenerConnected') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getDiagnostics() async {
    if (!isSupported) return {};
    try {
      final res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getCaptureDiagnostics');
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return {};
  }

  @override
  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    try {
      final nativeGranted =
          await _channel.invokeMethod<bool>('isNotificationPermissionGranted');
      if (nativeGranted ?? false) return true;
      return await NotificationListenerService.isPermissionGranted();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    try {
      final nativeResult =
          await _channel.invokeMethod<bool>('requestNotificationPermission');
      if (nativeResult ?? false) return true;
      return await NotificationListenerService.requestPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!isSupported) return false;
    try {
      return await _channel
              .invokeMethod<bool>('requestIgnoreBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isSupported) return true;
    try {
      return await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openAutostartSettings() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('openAutostartSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _subject.close();
}

/// Implementación vacía para iOS y tests.
class NoopNotificationListener implements NotificationListenerDataSource {
  @override
  Stream<RawNotification> get stream => const Stream.empty();

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> isListenerConnected() async => false;

  @override
  Future<Map<String, dynamic>> getDiagnostics() async => {};

  @override
  Future<void> flushPendingOfflineNotifications() async {}

  @override
  Future<void> markNotificationsProcessed(List<int> ids) async {}

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => false;

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<bool> openAutostartSettings() async => false;

  @override
  bool get isSupported => false;
}
