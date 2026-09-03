import '../../../../core/utils/result.dart';
import '../entities/chat_message.dart';

abstract interface class ChatRepository {
  Future<Result<ChatMessage>> askAssistant(String query);
}
