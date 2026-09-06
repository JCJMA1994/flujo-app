import 'package:equatable/equatable.dart';

import '../../../transactions/domain/entities/transaction.dart';

/// Notificación cruda tal como llegó del sistema, antes de interpretarla.
class RawNotification extends Equatable {
  const RawNotification({
    required this.packageName,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.id,
    this.notificationKey,
    this.notificationHash,
  });

  final int? id;
  final String? notificationKey;
  final String? notificationHash;
  final String packageName;
  final String title;
  final String body;
  final DateTime receivedAt;

  String get fullText => '$title $body';

  @override
  List<Object?> get props => [
        id,
        notificationKey,
        notificationHash,
        packageName,
        title,
        body,
        receivedAt,
      ];
}

/// Resultado de interpretar una notificación. Es intencionalmente parcial:
/// un parser puede sacar el monto pero no el comercio, y eso todavía sirve.
class ParsedExpense extends Equatable {
  const ParsedExpense({
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.occurredAt,
    required this.confidence,
    required this.rawText,
    this.type = TransactionType.expense,
    this.scope = TransactionScope.personal,
    this.bankId,
    this.suggestedCategoryId,
    this.parserVersion = '1.0.0',
    this.notificationHash,
    this.rawNotificationId,
  });

  final double amount;
  final String currency;
  final String merchant;
  final DateTime occurredAt;
  final TransactionType type;
  final TransactionScope scope;

  /// 1.0 = parser determinista con match exacto.
  /// 0.5–0.8 = inferido por IA.
  /// < 0.7 entra a la cola de revisión del usuario.
  final double confidence;

  final String rawText;
  final String? bankId;
  final String? suggestedCategoryId;
  final String parserVersion;
  final String? notificationHash;
  final int? rawNotificationId;

  ParsedExpense copyWith({
    String? suggestedCategoryId,
    TransactionType? type,
    TransactionScope? scope,
    double? confidence,
    String? bankId,
    String? parserVersion,
    String? notificationHash,
    int? rawNotificationId,
  }) {
    return ParsedExpense(
      amount: amount,
      currency: currency,
      merchant: merchant,
      occurredAt: occurredAt,
      type: type ?? this.type,
      scope: scope ?? this.scope,
      confidence: confidence ?? this.confidence,
      rawText: rawText,
      bankId: bankId ?? this.bankId,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      parserVersion: parserVersion ?? this.parserVersion,
      notificationHash: notificationHash ?? this.notificationHash,
      rawNotificationId: rawNotificationId ?? this.rawNotificationId,
    );
  }

  @override
  List<Object?> get props => [
        amount,
        currency,
        merchant,
        occurredAt,
        type,
        scope,
        confidence,
        rawText,
        bankId,
        suggestedCategoryId,
        parserVersion,
        notificationHash,
        rawNotificationId,
      ];
}

/// Regla que el usuario le enseñó a la app.
class UserRule extends Equatable {
  const UserRule({
    required this.id,
    required this.matcher,
    required this.value,
    required this.targetCategoryId,
    this.priority = 0,
  });

  final String id;
  final RuleMatcher matcher;
  final String value;
  final String targetCategoryId;
  final int priority;

  bool matches(ParsedExpense expense) {
    return switch (matcher) {
      RuleMatcher.merchantContains =>
        expense.merchant.toLowerCase().contains(value.toLowerCase()),
      RuleMatcher.amountBelow =>
        expense.amount < (double.tryParse(value) ?? double.infinity),
      RuleMatcher.amountAbove =>
        expense.amount > (double.tryParse(value) ?? double.infinity),
    };
  }

  @override
  List<Object?> get props => [id, matcher, value, targetCategoryId, priority];
}

enum RuleMatcher { merchantContains, amountBelow, amountAbove }
