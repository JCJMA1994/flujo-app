import 'package:equatable/equatable.dart';

import '../../domain/entities/chat_message.dart';

enum ChatStatus { initial, loading, success, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.activeChips = const [
      '¿En qué gasté más este mes?',
      '¿Cuánto gasté en comida?',
      '¿Cuál es mi balance neto?',
    ],
    this.errorMessage,
  });

  final ChatStatus status;
  final List<ChatMessage> messages;
  final List<String> activeChips;
  final String? errorMessage;

  ChatState copyWith({
    ChatStatus? status,
    List<ChatMessage>? messages,
    List<String>? activeChips,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      activeChips: activeChips ?? this.activeChips,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, messages, activeChips, errorMessage];
}
