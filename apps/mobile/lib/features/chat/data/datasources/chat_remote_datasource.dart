import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/chat_message.dart';

abstract interface class ChatRemoteDataSource {
  Future<ChatMessage> queryAssistant(String query);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  ChatRemoteDataSourceImpl({
    required Dio dio,
    Uuid? uuid,
  })  : _dio = dio,
        _uuid = uuid ?? const Uuid();

  final Dio _dio;
  final Uuid _uuid;

  @override
  Future<ChatMessage> queryAssistant(String query) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/chat/query',
        data: {'query': query},
      );

      final data = response.data;
      if (data == null) {
        throw const ServerFailure('Respuesta vacía del servidor');
      }

      final answer = data['answer'] as String? ?? 'No tengo información para esa consulta.';
      final chipsRaw = data['suggested_chips'] as List<dynamic>? ?? [];
      final chips = chipsRaw.map((e) => e.toString()).toList();

      return ChatMessage(
        id: _uuid.v4(),
        text: answer,
        isUser: false,
        timestamp: DateTime.now(),
        suggestedChips: chips,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) {
        throw const NetworkFailure();
      }
      throw ServerFailure(
        e.response?.data is Map<String, dynamic> &&
                (e.response!.data as Map)['error'] != null
            ? (e.response!.data as Map)['error'].toString()
            : (e.message ?? 'Error al comunicarse con el asistente'),
      );
    }
  }
}
