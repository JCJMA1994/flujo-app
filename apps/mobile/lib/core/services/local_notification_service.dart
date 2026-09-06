import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/transactions/domain/entities/transaction.dart';
import '../database/app_database.dart';
import '../di/injection.dart';

/// Callback de nivel superior para ejecutar acciones de notificación en segundo plano
/// sin requerir abrir la interfaz de usuario.
@pragma('vm:entry-point')
Future<void> notificationTapBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;

  if (response.actionId == 'action_confirm') {
    try {
      final db = AppDatabase();
      await (db.update(db.transactionsTable)..where((t) => t.id.equals(payload)))
          .write(
        const TransactionsTableCompanion(
          reviewed: Value(true),
          confidence: Value(1),
          syncedAt: Value(null),
        ),
      );
      await db.close();
      debugPrint(
        '[notificationTapBackground] Transacción $payload confirmada en segundo plano',
      );
    } catch (e) {
      debugPrint('[notificationTapBackground] Error al confirmar: $e');
    }
  }
}

/// Servicio centralizado de notificaciones locales del sistema operativo.
class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String channelId = 'flujo_transactions';
  static const String channelName = 'Movimientos y Pagos';
  static const String channelDescription =
      'Notificaciones interactivas para confirmar o editar gastos e ingresos';

  final _onReviewRequested = StreamController<String>.broadcast();
  Stream<String> get onReviewRequested => _onReviewRequested.stream;

  final _onConfirmRequested = StreamController<String>.broadcast();
  Stream<String> get onConfirmRequested => _onConfirmRequested.stream;

  String? _pendingReviewId;
  String? get pendingReviewId => _pendingReviewId;
  void clearPendingReviewId() => _pendingReviewId = null;

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
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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

    // Verificar si la app fue lanzada mediante el toque de una notificación
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        final res = details.notificationResponse;
        if (res != null) {
          unawaited(_handleNotificationResponse(res));
        }
      }
    } catch (_) {}

    _initialized = true;
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    debugPrint(
      '[LocalNotificationService] Respuesta de notificación: action=${response.actionId}, payload=$payload',
    );

    if (response.actionId == 'action_confirm') {
      _onConfirmRequested.add(payload);
      try {
        final db = getIt.isRegistered<AppDatabase>()
            ? getIt<AppDatabase>()
            : AppDatabase();
        await (db.update(db.transactionsTable)
              ..where((t) => t.id.equals(payload)))
            .write(
          const TransactionsTableCompanion(
            reviewed: Value(true),
            confidence: Value(1),
            syncedAt: Value(null),
          ),
        );
        debugPrint(
          '[LocalNotificationService] Transacción $payload confirmada en primer plano',
        );
      } catch (e) {
        debugPrint('[LocalNotificationService] Error confirmando: $e');
      }
    } else {
      // 'action_edit' o toque en el cuerpo de la notificación
      _pendingReviewId = payload;
      _onReviewRequested.add(payload);
    }
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

  /// Muestra una notificación interactiva con botones para confirmar y editar si
  /// la transacción está pendiente de revisión, o informativa si ya fue confirmada.
  Future<void> showTransactionNotification(Transaction transaction) async {
    try {
      await init();

      final isPendingReview = !transaction.reviewed;
      final isIncome = transaction.type == TransactionType.income;
      final formattedAmount =
          '${transaction.currency == 'USD' ? r'$' : 'S/'} ${transaction.amount.toStringAsFixed(2)}';

      final title = isPendingReview
          ? (isIncome
              ? '💰 ¿Confirmar ingreso: $formattedAmount?'
              : '💸 ¿Confirmar gasto: $formattedAmount?')
          : (isIncome
              ? '💰 Ingreso registrado: $formattedAmount'
              : '💸 Gasto registrado: $formattedAmount');

      final categoryInfo =
          '${transaction.category.name} ${transaction.category.emoji}';
      final body = isPendingReview
          ? '${transaction.merchant} · $categoryInfo (IA)'
          : '${transaction.merchant} · $categoryInfo';

      final origin =
          transaction.parser != null && transaction.parser != 'generic'
              ? transaction.parser!.toUpperCase()
              : (transaction.source == TransactionSource.bankNotification
                  ? 'NOTIFICACIÓN'
                  : 'COMPROBANTE');
      final scopeName = transaction.scope == TransactionScope.business
          ? '💼 Negocio'
          : '👤 Personal';

      final bigText = StringBuffer()
        ..writeln('🏪 Comercio: ${transaction.merchant}')
        ..writeln(
          isPendingReview
              ? '🏷️ Categoría sugerida (IA): $categoryInfo'
              : '🏷️ Categoría: $categoryInfo',
        )
        ..writeln('📱 Vía $origin · $scopeName')
        ..write(
          isPendingReview
              ? '👉 Presiona Confirmar para guardar o Editar para modificarla.'
              : '✅ Transacción confirmada en tu historial.',
        );

      final notificationColor =
          isIncome ? const Color(0xFF059669) : const Color(0xFF0D9488);

      final androidActions = isPendingReview
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'action_confirm',
                '✅ Confirmar',
              ),
              const AndroidNotificationAction(
                'action_edit',
                '✏️ Editar',
                showsUserInterface: true,
              ),
            ]
          : null;

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
          subText:
              isPendingReview ? 'Flujo · Por Confirmar' : 'Flujo · Finanzas',
          when: DateTime.now().millisecondsSinceEpoch,
          vibrationPattern: Int64List.fromList([0, 150, 80, 150]),
          ticker: title,
          category: AndroidNotificationCategory.status,
          actions: androidActions,
          styleInformation: BigTextStyleInformation(
            bigText.toString(),
            contentTitle: title,
            summaryText: isPendingReview
                ? '🤖 Categorizado por IA'
                : (isIncome
                    ? '✨ ¡Ingreso confirmado!'
                    : '⚡ Gasto capturado'),
          ),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: isPendingReview
              ? '🤖 Categorizado por IA'
              : (isIncome ? '✨ Ingreso confirmado' : '⚡ Gasto capturado'),
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

  void dispose() {
    _onReviewRequested.close();
    _onConfirmRequested.close();
  }
}
