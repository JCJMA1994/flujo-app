import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/flujo_feedback_modal.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/usecases/usecases.dart';
import '../../domain/entities/parsed_expense.dart';
import '../datasources/ai_categorizer_datasource.dart';

/// Servicio que intercepta imágenes o textos compartidos desde Yape, Plin u otras apps
/// mediante el menú "Compartir" de Android (Share Target) y los procesa con la IA del backend.
class ShareIntentService {
  ShareIntentService({
    required AiCategorizerDataSource aiCategorizer,
    required AddTransaction addTransaction,
    LocalNotificationService? notificationService,
    Uuid uuid = const Uuid(),
  })  : _ai = aiCategorizer,
        _addTransaction = addTransaction,
        _notificationService = notificationService,
        _uuid = uuid;

  final AiCategorizerDataSource _ai;
  final AddTransaction _addTransaction;
  final LocalNotificationService? _notificationService;
  final Uuid _uuid;

  /// Llave global para mostrar notificaciones / SnackBars en la pantalla
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static const _channel = MethodChannel('com.flujo.app/share');

  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedData') {
        final data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          await _handleData(data);
        }
      }
    });

    // Revisa si la app fue abierta en frío desde el menú compartir
    _channel.invokeMethod<Map<dynamic, dynamic>>('getSharedData').then((data) {
      if (data != null) {
        _handleData(data);
      }
    }).catchError((Object err) {
      debugPrint('Error al consultar getSharedData: $err');
    });
  }

  String? _lastProcessedSignature;
  DateTime? _lastProcessedTime;
  bool _isProcessing = false;
  final _recentSharedKeys = <String, DateTime>{};

  Future<void> _handleData(Map<dynamic, dynamic> data) async {
    final type = data['type'] as String?;
    var signature = '';

    if (type == 'image') {
      final bytes = data['bytes'] as Uint8List?;
      if (bytes == null || bytes.isEmpty) return;
      signature = 'img_${bytes.length}_${bytes.take(20).join(',')}';
    } else if (type == 'text') {
      final text = data['text'] as String?;
      if (text == null || text.trim().isEmpty) return;
      signature = 'txt_${text.trim().hashCode}';
    } else {
      return;
    }

    final now = DateTime.now();
    if (_isProcessing) {
      debugPrint(
        'ShareIntentService: Ya se está procesando un comprobante, omitiendo duplicado.',
      );
      return;
    }
    if (_lastProcessedSignature == signature &&
        _lastProcessedTime != null &&
        now.difference(_lastProcessedTime!) < const Duration(seconds: 15)) {
      debugPrint(
        'ShareIntentService: Comprobante idéntico recibido en menos de 15s, omitiendo.',
      );
      return;
    }

    _isProcessing = true;
    _lastProcessedSignature = signature;
    _lastProcessedTime = now;

    try {
      if (type == 'image') {
        final bytes = data['bytes'] as Uint8List;
        final mimeType = data['mimeType'] as String? ?? 'image/jpeg';
        await _processImage(bytes, mimeType);
      } else if (type == 'text') {
        final text = data['text'] as String;
        await _processText(text);
      }
    } finally {
      _isProcessing = false;
    }
  }

  BuildContext? _loadingContext;

  void _showLoading(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        _loadingContext = dialogCtx;
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 38,
                    height: 38,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: FlujoTokens.verdePetroleo,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _hideLoading() {
    if (_loadingContext != null && _loadingContext!.mounted) {
      Navigator.of(_loadingContext!).pop();
      _loadingContext = null;
    }
  }

  void _showSuccess(ParsedExpense expense) {
    _hideLoading();
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      FlujoFeedbackModal.showSuccess(
        context,
        title: '¡Comprobante registrado!',
        message:
            '${expense.currency} ${expense.amount.toStringAsFixed(2)} en ${expense.merchant}',
      );
    }
  }

  void _showError(String error) {
    _hideLoading();
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      FlujoFeedbackModal.showError(
        context,
        title: 'No se pudo registrar',
        message: error,
      );
    }
  }

  Future<void> _processImage(Uint8List bytes, String mimeType) async {
    _showLoading('Analizando comprobante con Gemini IA...');
    try {
      final result = await _ai.interpretImage(
        imageBytes: bytes,
        mimeType: mimeType,
      );

      await result.fold(
        onFailure: (f) async {
          debugPrint('Fallo al interpretar comprobante: ${f.message}');
          _showError(f.message);
        },
        onSuccess: (expense) async {
          await _saveParsedExpense(expense);
          _showSuccess(expense);
          appRouter.go(AppRoutes.transactions);
        },
      );
    } catch (e) {
      debugPrint('Error procesando imagen compartida: $e');
      _showError(e.toString());
    }
  }

  Future<void> _processText(String text) async {
    _showLoading('Interpretando texto de pago...');
    try {
      final result = await _ai.interpret(text);
      await result.fold(
        onFailure: (f) async {
          debugPrint('Fallo al interpretar texto compartido: ${f.message}');
          _showError(f.message);
        },
        onSuccess: (expense) async {
          await _saveParsedExpense(expense);
          _showSuccess(expense);
          appRouter.go(AppRoutes.transactions);
        },
      );
    } catch (e) {
      debugPrint('Error procesando texto compartido: $e');
      _showError(e.toString());
    }
  }

  Future<void> _saveParsedExpense(ParsedExpense expense) async {
    final now = DateTime.now();
    _recentSharedKeys.removeWhere(
      (_, time) => now.difference(time) > const Duration(minutes: 10),
    );

    final deduplicationKey =
        'item_${expense.merchant}_${expense.amount}_${expense.currency}_${expense.type.name}';
    if (_recentSharedKeys.containsKey(deduplicationKey)) {
      final lastSeen = _recentSharedKeys[deduplicationKey]!;
      if (now.difference(lastSeen) < const Duration(minutes: 3)) {
        debugPrint(
          '[ShareIntentService] Comprobante duplicado en ventana corta, omitiendo guardado.',
        );
        return;
      }
    }
    _recentSharedKeys[deduplicationKey] = now;

    final isIncome = expense.type == TransactionType.income;
    final defaultCatId = isIncome ? 'other_income' : 'other';
    final catId = expense.suggestedCategoryId ?? defaultCatId;
    final category = kDefaultCategories.firstWhere(
      (c) => c.id == catId,
      orElse: () => Category(
        id: defaultCatId,
        name: isIncome ? 'Otros ingresos' : 'Otros',
        emoji: isIncome ? '💵' : '💸',
      ),
    );

    final transaction = Transaction(
      id: _uuid.v4(),
      amount: expense.amount,
      currency: expense.currency,
      merchant: expense.merchant,
      // La hora del comprobante es la hora exacta en la que se procesa
      occurredAt: now,
      category: category,
      source: TransactionSource.manual,
      scope: expense.scope,
      type: expense.type,
      confidence: expense.confidence,
      rawText: expense.rawText,
    );

    final result = await _addTransaction(transaction);
    result.fold(
      onFailure: (_) {},
      onSuccess: (tx) {
        unawaited(_notificationService?.showTransactionNotification(tx));
      },
    );
  }
}
