import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/chat_message.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/chat_state.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ChatCubit>(),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    HapticFeedback.lightImpact();
    _controller.clear();
    context.read<ChatCubit>().sendMessage(clean);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asistente Flujo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Consulta tus gastos con IA',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: BlocConsumer<ChatCubit, ChatState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.messages.length != curr.messages.length ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          _scrollToBottom();
          if (state.status == ChatStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
        buildWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.messages != curr.messages ||
            prev.activeChips != curr.activeChips,
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: state.messages.isEmpty
                    ? _EmptyChatWelcome(onChipSelected: _handleSend)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final msg = state.messages[index];
                          return _MessageBubble(message: msg);
                        },
                      ),
              ),
              if (state.status == ChatStatus.loading) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Analizando tus movimientos...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.activeChips.isNotEmpty) ...[
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.activeChips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final chip = state.activeChips[index];
                      return ActionChip(
                        label: Text(chip),
                        onPressed: () => _handleSend(chip),
                        avatar: const Icon(Icons.touch_app_outlined, size: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _InputField(
                controller: _controller,
                onSubmitted: _handleSend,
                isLoading: state.status == ChatStatus.loading,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyChatWelcome extends StatelessWidget {
  const _EmptyChatWelcome({required this.onChipSelected});

  final ValueChanged<String> onChipSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¿Qué deseas saber sobre tus gastos?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes hacerme preguntas en lenguaje natural sobre tus compras, suscripciones o tu balance del mes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  label: const Text('¿En qué gasté más este mes?'),
                  onPressed: () =>
                      onChipSelected('¿En qué gasté más este mes?'),
                ),
                ActionChip(
                  label: const Text('¿Cuánto gasté en comida?'),
                  onPressed: () => onChipSelected('¿Cuánto gasté en comida?'),
                ),
                ActionChip(
                  label: const Text('¿Cuál es mi balance neto?'),
                  onPressed: () => onChipSelected('¿Cuál es mi balance neto?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            if (!isUser) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copiado al portapapeles'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copiar',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.onSubmitted,
    required this.isLoading,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Pregunta algo sobre tus finanzas...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: isLoading ? null : onSubmitted,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isLoading ? null : () => onSubmitted(controller.text),
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
