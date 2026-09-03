import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class AskFinancialAssistant {
  const AskFinancialAssistant(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatMessage>> call(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return Future.value(
        const FailureResult(ValidationFailure('La consulta no puede estar vacía')),
      );
    }
    return _repository.askAssistant(cleanQuery);
  }
}
