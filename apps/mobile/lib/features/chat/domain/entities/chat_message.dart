import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.suggestedChips = const [],
  });

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> suggestedChips;

  @override
  List<Object?> get props => [id, text, isUser, timestamp, suggestedChips];
}
