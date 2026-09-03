import 'package:dio/dio.dart';

import '../models/transaction_model.dart';

abstract interface class TransactionRemoteDataSource {
  /// Envía los cambios locales y devuelve los ids que el server confirmó.
  Future<List<String>> push(List<TransactionModel> models);

  Future<List<TransactionModel>> pullSince(DateTime cursor);
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  TransactionRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<String>> push(List<TransactionModel> models) async {
    if (models.isEmpty) return const [];

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/transactions/sync',
      data: {
        'transactions': models.map((m) => m.toJson()).toList(),
      },
    );

    final data = response.data;
    if (data == null) return const [];

    final acknowledged = data['acknowledged'] as List<dynamic>?;
    return acknowledged?.map((id) => id.toString()).toList() ?? const [];
  }

  @override
  Future<List<TransactionModel>> pullSince(DateTime cursor) async {
    final response = await _dio.get<dynamic>(
      '/v1/transactions',
      queryParameters: {
        'since': cursor.toIso8601String(),
      },
    );

    final data = response.data;
    if (data == null) return const [];

    final list = switch (data) {
      final List<dynamic> items => items,
      final Map<String, dynamic> map =>
        map['transactions'] as List<dynamic>? ?? const [],
      _ => const <dynamic>[],
    };

    return list
        .whereType<Map<String, dynamic>>()
        .map(TransactionModel.fromJson)
        .toList();
  }
}
