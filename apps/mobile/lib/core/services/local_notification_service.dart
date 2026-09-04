import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/transactions/domain/entities/transaction.dart';

/// Servicio centralizado de notificaciones locales del sistema operativo.
class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'flujo_transactions';
  static const String channelName = 'Movimientos y Pagos';
  static const String channelDescription =
      'Notificaciones de confirmación cuando se registra un gasto o ingreso';

  bool _initialized = false;

  /// Inicializa los canales y listeners nativos de notificaciones locales.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint(
          '[LocalNotificationService] Notificación pulsada con payload: ${response.payload}',
        );
      },
    );

    // En Android creamos explícitamente el canal con alta prioridad y sonido
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        );
        await androidPlugin.createNotificationChannel(channel);
      }
    }

    _initialized = true;
  }

  /// Solicita permisos de notificación en Android 13+ (Tiramisu) y iOS.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Muestra una notificación formateada con los datos del gasto o ingreso procesado.
  Future<void> showTransactionNotification(Transaction transaction) async {
    try {
      await init();

      final isIncome = transaction.type == TransactionType.income;
      final titlePrefix = isIncome ? '💰 Ingreso registrado' : '💸 Gasto registrado';
      final formattedAmount =
          '${transaction.currency == 'USD' ? r'$' : 'S/'} ${transaction.amount.toStringAsFixed(2)}';
      final title = '$titlePrefix: $formattedAmount';

      final categoryInfo =
          '${transaction.category.name} ${transaction.category.emoji}';
      final body = '${transaction.merchant} · $categoryInfo';

      final origin = transaction.parser != null && transaction.parser != 'generic'
          ? transaction.parser!.toUpperCase()
          : (transaction.source == TransactionSource.bankNotification
              ? 'NOTIFICACIÓN'
              : 'COMPROBANTE');
      final scopeName = transaction.scope == TransactionScope.business
          ? '💼 Negocio'
          : '👤 Personal';

      final bigText = StringBuffer()
        ..writeln('🏪 ${transaction.merchant}')
        ..writeln('🏷️ $categoryInfo')
        ..write('📱 Vía $origin · $scopeName');

      final notificationColor = isIncome
          ? const Color(0xFF059669)
          : const Color(0xFF0D9488);

      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon:
              const DrawableResourceAndroidBitmap('ic_notification_large'),
          color: notificationColor,
          subText: 'Flujo · Finanzas',
          when: DateTime.now().millisecondsSinceEpoch,
          vibrationPattern: Int64List.fromList([0, 150, 80, 150]),
          ticker: title,
          category: AndroidNotificationCategory.status,
          styleInformation: BigTextStyleInformation(
            bigText.toString(),
            contentTitle: title,
            summaryText: isIncome ? '✨ ¡Ingreso confirmado!' : '⚡ Gasto capturado al instante',
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: isIncome ? '✨ Ingreso confirmado' : '⚡ Gasto capturado',
        ),
      );

      final notificationId = transaction.id.hashCode.abs();
      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: transaction.id,
      );
    } catch (e) {
      debugPrint(
        '[LocalNotificationService] Error al emitir notificación local: $e',
      );
    }
  }
}
