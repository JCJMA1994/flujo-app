import '../../domain/entities/transaction.dart';

/// El modelo vive en `data` y conoce JSON y columnas. La entidad no.
/// Separarlos evita que un cambio en la API te obligue a tocar el dominio.
class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.occurredAt,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.source,
    required this.scope,
    required this.confidence,
    required this.reviewed,
    this.type = 'expense',
    this.rawText,
    this.syncedAt,
    this.parser,
    this.parserVersion,
    this.notificationHash,
    this.rawNotificationId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'PEN',
      merchant: json['merchant'] as String,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      categoryEmoji: json['category_emoji'] as String? ?? '💸',
      source: json['source'] as String,
      scope: json['scope'] as String? ?? 'personal',
      type: json['type'] as String? ?? 'expense',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      reviewed: json['reviewed'] as bool? ?? true,
      rawText: json['raw_text'] as String?,
      syncedAt: json['synced_at'] == null
          ? null
          : DateTime.parse(json['synced_at'] as String),
      parser: json['parser'] as String?,
      parserVersion: json['parser_version'] as String?,
      notificationHash: json['notification_hash'] as String?,
      rawNotificationId: json['raw_notification_id'] as String?,
    );
  }

  factory TransactionModel.fromEntity(Transaction entity) {
    return TransactionModel(
      id: entity.id,
      amount: entity.amount,
      currency: entity.currency,
      merchant: entity.merchant,
      occurredAt: entity.occurredAt,
      categoryId: entity.category.id,
      categoryName: entity.category.name,
      categoryEmoji: entity.category.emoji,
      source: entity.source.name,
      scope: entity.scope.name,
      type: entity.type.name,
      confidence: entity.confidence,
      reviewed: entity.reviewed,
      rawText: entity.rawText,
      parser: entity.parser,
      parserVersion: entity.parserVersion,
      notificationHash: entity.notificationHash,
      rawNotificationId: entity.rawNotificationId,
    );
  }

  final String id;
  final double amount;
  final String currency;
  final String merchant;
  final DateTime occurredAt;
  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final String source;
  final String scope;
  final String type;
  final double confidence;
  final bool reviewed;
  final String? rawText;
  final DateTime? syncedAt;
  final String? parser;
  final String? parserVersion;
  final String? notificationHash;
  final String? rawNotificationId;

  bool get isPendingSync => syncedAt == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'currency': currency,
        'merchant': merchant,
        'occurred_at': occurredAt.toIso8601String(),
        'category_id': categoryId,
        'category_name': categoryName,
        'category_emoji': categoryEmoji,
        'source': source,
        'scope': scope,
        'type': type,
        'confidence': confidence,
        'reviewed': reviewed,
        'raw_text': rawText,
        'parser': parser,
        'parser_version': parserVersion,
        'notification_hash': notificationHash,
        'raw_notification_id': rawNotificationId,
      };

  Transaction toEntity() => Transaction(
        id: id,
        amount: amount,
        currency: currency,
        merchant: merchant,
        occurredAt: occurredAt,
        category: Category(
          id: categoryId,
          name: categoryName,
          emoji: categoryEmoji,
        ),
        source: TransactionSource.values.firstWhere(
          (s) => s.name == source,
          orElse: () => TransactionSource.manual,
        ),
        scope: TransactionScope.values.firstWhere(
          (s) => s.name == scope,
          orElse: () => TransactionScope.personal,
        ),
        type: TransactionType.values.firstWhere(
          (t) => t.name == type,
          orElse: () => TransactionType.expense,
        ),
        confidence: confidence,
        rawText: rawText,
        reviewed: reviewed,
        parser: parser,
        parserVersion: parserVersion,
        notificationHash: notificationHash,
        rawNotificationId: rawNotificationId,
      );
}
