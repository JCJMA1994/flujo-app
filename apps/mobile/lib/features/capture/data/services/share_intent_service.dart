import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

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
    Uuid uuid = const Uuid(),
  })  : _ai = aiCategorizer,
        _addTransaction = addTransaction,
        _uuid = uuid;

  final AiCategorizerDataSource _ai;
  final AddTransaction _addTransaction;
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

  void _showLoading(String message) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 15),
        ),
      );
  }

  void _showSuccess(ParsedExpense expense) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '✅ Comprobante registrado: ${expense.currency} ${expense.amount.toStringAsFixed(2)} - ${expense.merchant}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
  }

  void _showError(String error) {
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          content: Text(
            '❌ Falló el análisis: $error',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
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
        },
      );
    } catch (e) {
      debugPrint('Error procesando texto compartido: $e');
      _showError(e.toString());
    }
  }

  Future<void> _saveParsedExpense(ParsedExpense expense) async {
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
      occurredAt: expense.occurredAt,
      category: category,
      source: TransactionSource.manual,
      scope: expense.scope,
      type: expense.type,
      confidence: expense.confidence,
      rawText: expense.rawText,
    );

    await _addTransaction(transaction);
  }
}
