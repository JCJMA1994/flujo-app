import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/parsed_expense.dart';
import 'ai_categorizer_datasource.dart';

/// Implementación de [AiCategorizerDataSource] utilizando Google Gemini Flash.
/// Interpreta texto de notificaciones bancarias, vouchers y recibos (Yape, Plin,
/// BCP, Interbank, BBVA) extrayendo semánticamente el monto, sujeto y si es
/// cuenta personal o empresarial.
class GeminiAiCategorizerDataSource implements AiCategorizerDataSource {
  GeminiAiCategorizerDataSource({
    required Dio dio,
    required FlutterSecureStorage storage,
    String? defaultApiKey,
  })  : _dio = dio,
        _storage = storage,
        _defaultApiKey = defaultApiKey;

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final String? _defaultApiKey;

  static const _storageKey = 'gemini_api_key';
  static const _model = 'gemini-flash-latest';

  static const _systemInstruction = '''
Eres un asistente experto de finanzas personales y empresariales en Perú. Tu función es analizar imágenes de comprobantes/vouchers (Yape, Plin, BCP, BBVA, Interbank, etc.) y textos de notificaciones bancarias peruanas.

Extrae con máxima precisión los siguientes datos en un objeto JSON:
{
  "amount": number (monto numérico positivo, ej: 15.00),
  "currency": "PEN" o "USD",
  "merchant": string (nombre limpio del comercio, empresa o persona destinataria/remitente. Ej: "Juan Pérez", "Bodega Don Pepe", "Bembos", "Inkafarma". NUNCA devuelvas "Yape", "Plin" o "Comprobante" como merchant),
  "type": "income" (si recibió dinero, "¡Te yapearon!", abono, transferencia recibida) o "expense" (si pagó, "¡Yapeaste!", "Enviaste a", compra, débito),
  "scope": "personal" o "business" ("business" si menciona Yape Empresa, Plin para negocios, RUC, o se trata de una cuenta corporativa; de lo contrario "personal"),
  "category_id": string (OBLIGATORIAMENTE uno de los siguientes IDs exactos según el giro o concepto):
    - Para gastos:
      * "food": Restaurantes, chifas, pollerías, cafeterías, menús, almuerzos, cenas.
      * "delivery": Apps de delivery como Rappi, PedidosYa.
      * "groceries": Supermercados (Metro, Plaza Vea, Tottus, Wong), bodegas, minimarkets (Tambo, Oxxo), mercados de abastos.
      * "transport": Taxis (Uber, Didi, Indrive, Cabify), pasajes, gasolina/combustible (Primax, Repsol), peajes.
      * "services": Luz, agua, gas (Cálidda), telefonía e internet (Claro, Movistar, Entel, Bitel).
      * "health": Farmacias (Inkafarma, Mifarma), clínicas, médicos, consultas, laboratorios.
      * "shopping": Ropa, calzado, tecnología, tiendas por departamento (Falabella, Ripley), ferreterías, compras en general.
      * "subscriptions": Streaming y servicios digitales (Netflix, Spotify, YouTube, Disney).
      * "ants": Gastos hormiga pequeños (quioscos, golosinas, cafés al paso menores a S/ 10).
      * "other": Pagos diversos entre personas o conceptos no clasificables en las anteriores.
    - Para ingresos:
      * "salary": Sueldo, nómina, quincena, haberes de trabajo.
      * "freelance": Honorarios, ventas de negocio, cobros a clientes por servicios.
      * "investments": Rendimientos, intereses, dividendos.
      * "gifts": Regalos, premios, propinas recibidas.
      * "other_income": Otros abonos o ingresos.
  "bank_id": string ("yape", "plin", "bcp", "interbank", "bbva", "scotiabank" o "other"),
  "confidence": number (entre 0.0 y 1.0)
}

Responde ÚNICAMENTE con el objeto JSON válido.
''';

  String? _cleanKey(String? key) {
    if (key == null) return null;
    var trimmed = key.trim();
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      trimmed = trimmed.substring(1, trimmed.length - 1).trim();
    }
    return trimmed.isNotEmpty ? trimmed : null;
  }

  Future<String?> getApiKey() async {
    final storedKey = await _storage.read(key: _storageKey);
    final cleanStored = _cleanKey(storedKey);
    if (cleanStored != null) {
      return cleanStored;
    }
    return _cleanKey(_defaultApiKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    final clean = _cleanKey(apiKey);
    if (clean != null) {
      await _storage.write(key: _storageKey, value: clean);
    }
  }

  String? _extractServerError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return error['message'] as String?;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _executeWithRetry(
    List<Map<String, dynamic>> contents,
    String apiKey,
  ) async {
    final modelsToTry = [_model, 'gemini-1.5-flash'];
    DioException? lastDioException;

    for (final model in modelsToTry) {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
      final requestBody = {
        'systemInstruction': {
          'parts': [
            {'text': _systemInstruction},
          ],
        },
        'contents': contents,
        'generationConfig': {
          'responseMimeType': 'application/json',
          'temperature': 0.1,
        },
      };

      for (var attempt = 1; attempt <= 2; attempt++) {
        try {
          final response = await _dio.post<Map<String, dynamic>>(
            url,
            data: requestBody,
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'X-goog-api-key': apiKey,
              },
              sendTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 40),
            ),
          );
          return response.data;
        } on DioException catch (e) {
          lastDioException = e;
          final statusCode = e.response?.statusCode;
          final errorMsg = _extractServerError(e);

          final isHighDemandOrTimeout = statusCode == 503 ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionTimeout ||
              (errorMsg?.contains('high demand') ?? false);

          if (isHighDemandOrTimeout && attempt < 2) {
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            continue;
          }
          break;
        }
      }
    }

    if (lastDioException != null) {
      throw lastDioException;
    }
    return null;
  }

  Result<ParsedExpense> _parseResponse(
    Map<String, dynamic>? data, {
    required String fallbackMerchant,
    required String rawText,
  }) {
    final candidates = data?['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return FailureResult(
        ParseFailure('Gemini no devolvió resultados', rawText: rawText),
      );
    }

    final firstCandidate = candidates.first as Map<String, dynamic>;
    final content = firstCandidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final firstPart = parts?.first as Map<String, dynamic>?;
    final jsonText = firstPart?['text'] as String?;

    if (jsonText == null || jsonText.trim().isEmpty) {
      return FailureResult(
        ParseFailure('Respuesta vacía de Gemini', rawText: rawText),
      );
    }

    try {
      final parsedJson = jsonDecode(jsonText) as Map<String, dynamic>;
      final amountNum = parsedJson['amount'] as num?;
      if (amountNum == null) {
        return FailureResult(
          ParseFailure(
            'No se detectó un monto numérico válido en el comprobante',
            rawText: rawText,
          ),
        );
      }

      final typeStr =
          (parsedJson['type'] as String? ?? 'expense').toLowerCase();
      final isIncome = typeStr == 'income';
      final scopeStr =
          (parsedJson['scope'] as String? ?? 'personal').toLowerCase();
      final scope = scopeStr == 'business'
          ? TransactionScope.business
          : TransactionScope.personal;

      final categoryId = parsedJson['category_id'] as String?;
      final defaultCat = isIncome ? 'other_income' : 'other';

      return Success(
        ParsedExpense(
          amount: amountNum.toDouble().abs(),
          currency: parsedJson['currency'] as String? ?? 'PEN',
          merchant: parsedJson['merchant'] as String? ?? fallbackMerchant,
          occurredAt: DateTime.now(),
          type: isIncome ? TransactionType.income : TransactionType.expense,
          scope: scope,
          confidence: (parsedJson['confidence'] as num?)?.toDouble() ?? 0.95,
          rawText: rawText,
          bankId: parsedJson['bank_id'] as String?,
          suggestedCategoryId: categoryId ?? defaultCat,
        ),
      );
    } catch (e) {
      return FailureResult(
        ParseFailure('Formato JSON inválido de Gemini: $e', rawText: rawText),
      );
    }
  }

  @override
  Future<Result<ParsedExpense>> interpret(String rawText) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const FailureResult(
        ParseFailure('No se ha configurado la API Key de Gemini.'),
      );
    }

    try {
      final contents = [
        {
          'parts': [
            {'text': 'Analiza esta notificación o comprobante: "$rawText"'},
          ],
        },
      ];
      final data = await _executeWithRetry(contents, apiKey);
      return _parseResponse(
        data,
        fallbackMerchant: 'Desconocido',
        rawText: rawText,
      );
    } on DioException catch (e) {
      final serverMsg = _extractServerError(e);
      return FailureResult(
        e.type == DioExceptionType.connectionError
            ? const NetworkFailure()
            : ServerFailure(
                serverMsg ?? e.message ?? 'Error de conexión con Gemini',
              ),
      );
    } catch (e) {
      return FailureResult(ParseFailure(e.toString(), rawText: rawText));
    }
  }

  @override
  Future<Result<ParsedExpense>> interpretImage({
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const FailureResult(
        ParseFailure(
          'No se ha configurado la API Key de Gemini en el archivo .env',
        ),
      );
    }

    try {
      final contents = [
        {
          'parts': [
            {
              'text':
                  'Analiza detenidamente esta imagen de comprobante o voucher de pago peruano (Yape, Plin, BCP, etc.). Identifica el destinatario o remitente ("merchant"), el monto ("amount"), si es ingreso o gasto ("type"), y clasifícalo en la mejor "category_id" según el giro del negocio, nombre de la persona o nota/motivo del pago.',
            },
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ];
      final data = await _executeWithRetry(contents, apiKey);
      return _parseResponse(
        data,
        fallbackMerchant: 'Comprobante compartido',
        rawText: 'Comprobante compartido vía imagen',
      );
    } on DioException catch (e) {
      final serverMsg = _extractServerError(e);
      return FailureResult(
        e.type == DioExceptionType.connectionError
            ? const NetworkFailure()
            : ServerFailure(
                serverMsg ?? e.message ?? 'Error de conexión con Gemini',
              ),
      );
    } catch (e) {
      return FailureResult(ParseFailure(e.toString()));
    }
  }
}
