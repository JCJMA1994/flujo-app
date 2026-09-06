import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/parsed_expense.dart';
import '../datasources/ai_categorizer_datasource.dart';
import '../parsers/bank_parsers.dart';

/// Orquesta las tres etapas de interpretación en orden de costo creciente:
///
///   1. Parser determinista por banco  → gratis, instantáneo, ~80% de casos
///   2. LLM en el backend              → paga, con latencia, solo lo raro
///   3. Reglas del usuario             → siempre ganan, van al final
///
/// El orden importa: no tiene sentido gastar una llamada de IA en algo que
/// una regex resuelve, ni dejar que la IA sobrescriba lo que el usuario
/// enseñó explícitamente.
class ExpenseParsingPipeline {
  ExpenseParsingPipeline({
    required List<BankParser> parsers,
    required AiCategorizerDataSource aiCategorizer,
  })  : _parsers = parsers,
        _ai = aiCategorizer;

  final List<BankParser> _parsers;
  final AiCategorizerDataSource _ai;

  Future<Result<ParsedExpense>> process(
    RawNotification notification, {
    required List<UserRule> rules,
  }) async {
    ParsedExpense? expense;

    // Etapa 1: Motor de Inteligencia Artificial (Gemini).
    // Prioridad máxima según requerimiento: interpretación semántica inteligente
    // de comercios, montos y categorías sin depender de regex rígidas.
    final aiResult = await _ai.interpret(notification.fullText);
    expense = aiResult.fold<ParsedExpense?>(
      onFailure: (_) => null,
      onSuccess: (parsed) => parsed.copyWith(
        notificationHash: notification.notificationHash,
        rawNotificationId: notification.id,
      ),
    );

    // Etapa 2: Fallback determinista local (Yape, Plin, BCP, Interbank).
    // Si la IA falla (sin internet, timeout, error del backend), los parsers locales
    // actúan de red de seguridad para no perder ninguna transacción.
    if (expense == null) {
      for (final parser in _parsers) {
        if (!parser.canHandle(notification)) continue;
        final parsed = parser.parse(notification);
        if (parsed != null && parsed.confidence >= 0.8) {
          expense = parsed.copyWith(
            notificationHash: notification.notificationHash,
            rawNotificationId: notification.id,
          );
          break;
        }
      }
    }

    if (expense == null) {
      return FailureResult(
        ParseFailure(
          'No reconocimos un movimiento financiero en esta notificación',
          rawText: notification.fullText,
        ),
      );
    }

    // Etapa 3: Reglas del usuario, por prioridad descendente.
    final applicable = rules.where((r) => r.matches(expense!)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    if (applicable.isNotEmpty) {
      expense = expense.copyWith(
        suggestedCategoryId: applicable.first.targetCategoryId,
        confidence: 1,
      );
    }

    return Success(expense);
  }
}
