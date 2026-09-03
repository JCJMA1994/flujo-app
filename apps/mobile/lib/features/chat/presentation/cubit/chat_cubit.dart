import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/usecases/ask_financial_assistant.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required AskFinancialAssistant askFinancialAssistant,
    Uuid? uuid,
  })  : _askFinancialAssistant = askFinancialAssistant,
        _uuid = uuid ?? const Uuid(),
        super(const ChatState());

  final AskFinancialAssistant _askFinancialAssistant;
  final Uuid _uuid;

  Future<void> sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: clean,
      isUser: true,
      timestamp: DateTime.now(),
    );

    final updated = List<ChatMessage>.from(state.messages)..add(userMessage);
    emit(state.copyWith(status: ChatStatus.loading, messages: updated));

    final result = await _askFinancialAssistant(clean);
    result.fold(
      onSuccess: (assistantMessage) {
        final withAssistant = List<ChatMessage>.from(state.messages)..add(assistantMessage);
        emit(
          state.copyWith(
            status: ChatStatus.success,
            messages: withAssistant,
            activeChips: assistantMessage.suggestedChips.isNotEmpty
                ? assistantMessage.suggestedChips
                : state.activeChips,
          ),
        );
      },
      onFailure: (failure) {
        emit(
          state.copyWith(
            status: ChatStatus.error,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }
}
