import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/parsed_expense.dart';

abstract interface class AiCategorizerDataSource {
  Future<Result<ParsedExpense>> interpret(String rawText);
  Future<Result<ParsedExpense>> interpretImage({
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
  });
}

/// La llamada al modelo vive en TU backend, no en la app.
///
/// Poner la API key de un proveedor de IA dentro del binario equivale a
/// publicarla: cualquiera puede extraerla de un APK. Además, centralizar
/// permite cachear, limitar por usuario y cambiar de modelo sin publicar
/// una versión nueva.
class RemoteAiCategorizerDataSource implements AiCategorizerDataSource {
  RemoteAiCategorizerDataSource(this._dio);

  final Dio _dio;

  @override
  Future<Result<ParsedExpense>> interpret(String rawText) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/capture/interpret',
        data: {'raw_text': rawText},
      );

      final data = response.data;
      if (data == null || data['amount'] == null) {
        return FailureResult(
          ParseFailure('El modelo no encontró un gasto', rawText: rawText),
        );
      }

      final typeStr = (data['type'] as String? ?? 'expense').toLowerCase();
      final transactionType =
          typeStr == 'income' ? TransactionType.income : TransactionType.expense;

      return Success(
        ParsedExpense(
          amount: (data['amount'] as num).toDouble(),
          currency: data['currency'] as String? ?? 'PEN',
          merchant: data['merchant'] as String? ?? 'Sin identificar',
          occurredAt: data['occurred_at'] != null
              ? DateTime.parse(data['occurred_at'] as String)
              : DateTime.now(),
          type: transactionType,
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.6,
          rawText: rawText,
          bankId: data['bank_id'] as String?,
          suggestedCategoryId: data['category_id'] as String?,
        ),
      );
    } on DioException catch (e) {
      return FailureResult(
        e.type == DioExceptionType.connectionError
            ? const NetworkFailure()
            : ServerFailure(e.message ?? 'Error al interpretar'),
      );
    }
  }

  @override
  Future<Result<ParsedExpense>> interpretImage({
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/capture/interpret-image',
        data: {
          'image_base64': base64Encode(imageBytes),
          'mime_type': mimeType,
        },
      );

      final data = response.data;
      if (data == null || data['amount'] == null) {
        return const FailureResult(
          ParseFailure(
            'El servidor no detectó un comprobante financiero válido',
          ),
        );
      }

      final typeStr = (data['type'] as String? ?? 'expense').toLowerCase();
      final transactionType =
          typeStr == 'income' ? TransactionType.income : TransactionType.expense;

      return Success(
        ParsedExpense(
          amount: (data['amount'] as num).toDouble(),
          currency: data['currency'] as String? ?? 'PEN',
          merchant: data['merchant'] as String? ?? 'Comprobante compartido',
          occurredAt: data['occurred_at'] != null
              ? DateTime.parse(data['occurred_at'] as String)
              : DateTime.now(),
          type: transactionType,
          confidence: (data['confidence'] as num?)?.toDouble() ?? 0.85,
          rawText: 'Comprobante compartido vía imagen',
          bankId: data['bank_id'] as String?,
          suggestedCategoryId: data['category_id'] as String?,
        ),
      );
    } on DioException catch (e) {
      return FailureResult(
        e.type == DioExceptionType.connectionError
            ? const NetworkFailure()
            : ServerFailure(
                e.message ??
                    'Error de conexión con el servidor al interpretar imagen',
              ),
      );

    } catch (e) {
      return FailureResult(ParseFailure(e.toString()));
    }
  }
}
