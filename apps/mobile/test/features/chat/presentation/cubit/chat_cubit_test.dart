import 'package:bloc_test/bloc_test.dart';
import 'package:flujo/core/error/failures.dart';
import 'package:flujo/core/utils/result.dart';
import 'package:flujo/features/chat/domain/entities/chat_message.dart';
import 'package:flujo/features/chat/domain/usecases/ask_financial_assistant.dart';
import 'package:flujo/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:flujo/features/chat/presentation/cubit/chat_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAskFinancialAssistant extends Mock implements AskFinancialAssistant {}

void main() {
  late MockAskFinancialAssistant mockAskAssistant;
  late ChatCubit cubit;

  final tAssistantMessage = ChatMessage(
    id: 'msg-2',
    text: 'Gastaste S/ 450 en comida este mes.',
    isUser: false,
    timestamp: DateTime(2026, 4, 15),
    suggestedChips: const ['¿Cuánto en transporte?'],
  );

  setUp(() {
    mockAskAssistant = MockAskFinancialAssistant();
    cubit = ChatCubit(askFinancialAssistant: mockAskAssistant);
  });

  tearDown(() {
    cubit.close();
  });

  group('ChatCubit', () {
    test('estado inicial tiene ChatStatus.initial y chips por defecto', () {
      expect(cubit.state.status, equals(ChatStatus.initial));
      expect(cubit.state.messages, isEmpty);
      expect(cubit.state.activeChips, isNotEmpty);
    });

    blocTest<ChatCubit, ChatState>(
      'sendMessage emite loading y luego success ante respuesta del asistente',
      build: () {
        when(() => mockAskAssistant('¿Cuánto gasté en comida?'))
            .thenAnswer((_) async => Success(tAssistantMessage));
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('¿Cuánto gasté en comida?'),
      expect: () => [
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatStatus.loading)
            .having((s) => s.messages.length, 'messages.length', 1),
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatStatus.success)
            .having((s) => s.messages.length, 'messages.length', 2)
            .having(
              (s) => s.messages.last.text,
              'text',
              'Gastaste S/ 450 en comida este mes.',
            )
            .having(
          (s) => s.activeChips,
          'activeChips',
          ['¿Cuánto en transporte?'],
        ),
      ],
    );

    blocTest<ChatCubit, ChatState>(
      'sendMessage emite loading y luego error ante fallo de red o servidor',
      build: () {
        when(() => mockAskAssistant('consulta')).thenAnswer(
          (_) async => const FailureResult(ServerFailure('Error del servidor')),
        );
        return cubit;
      },
      act: (cubit) => cubit.sendMessage('consulta'),
      expect: () => [
        isA<ChatState>().having((s) => s.status, 'status', ChatStatus.loading),
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Error del servidor',
            ),
      ],
    );
  });
}
