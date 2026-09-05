import 'package:equatable/equatable.dart';

enum TransactionType { expense, income }

enum TransactionSource { manual, bankNotification, email, whatsapp }

enum TransactionScope { personal, business }

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
  });

  final String id;
  final String name;
  final String emoji;

  @override
  List<Object?> get props => [id, name, emoji];
}

const kExpenseCategories = <Category>[
  Category(id: 'food', name: 'Comida', emoji: '🍔'),
  Category(id: 'transport', name: 'Transporte', emoji: '🚕'),
  Category(id: 'delivery', name: 'Delivery', emoji: '🛵'),
  Category(id: 'groceries', name: 'Supermercado', emoji: '🛒'),
  Category(id: 'services', name: 'Servicios', emoji: '💡'),
  Category(id: 'health', name: 'Salud', emoji: '💊'),
  Category(id: 'shopping', name: 'Compras', emoji: '🛍️'),
  Category(id: 'subscriptions', name: 'Suscripciones', emoji: '📺'),
  Category(id: 'ants', name: 'Gastos hormiga', emoji: '🐜'),
  Category(id: 'other', name: 'Otros gastos', emoji: '💸'),
];

const kIncomeCategories = <Category>[
  Category(id: 'salary', name: 'Sueldo', emoji: '💰'),
  Category(id: 'freelance', name: 'Honorarios / Ventas', emoji: '💼'),
  Category(id: 'investments', name: 'Inversiones', emoji: '📈'),
  Category(id: 'gifts', name: 'Regalos / Premios', emoji: '🎁'),
  Category(id: 'other_income', name: 'Otros ingresos', emoji: '💵'),
];

const kDefaultCategories = <Category>[
  ...kExpenseCategories,
  ...kIncomeCategories,
];

class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.occurredAt,
    required this.category,
    required this.source,
    required this.scope,
    this.type = TransactionType.expense,
    this.confidence = 1.0,
    this.rawText,
    this.reviewed = true,
    this.parser,
    this.parserVersion,
    this.notificationHash,
    this.rawNotificationId,
  });

  final String id;
  final double amount;
  final String currency;
  final String merchant;
  final DateTime occurredAt;
  final Category category;
  final TransactionSource source;
  final TransactionScope scope;
  final TransactionType type;

  /// Confianza del parser/IA. Por debajo de 0.7 va a la cola de revisión.
  final double confidence;

  /// Texto original de la notificación.
  final String? rawText;

  final bool reviewed;

  final String? parser;
  final String? parserVersion;
  final String? notificationHash;
  final String? rawNotificationId;

  bool get needsReview => !reviewed || confidence < 0.7;
  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  Transaction copyWith({
    Category? category,
    TransactionScope? scope,
    TransactionType? type,
    bool? reviewed,
    double? amount,
    String? merchant,
    double? confidence,
    String? rawText,
    DateTime? occurredAt,
    String? parser,
    String? parserVersion,
    String? notificationHash,
    String? rawNotificationId,
  }) {
    return Transaction(
      id: id,
      amount: amount ?? this.amount,
      currency: currency,
      merchant: merchant ?? this.merchant,
      occurredAt: occurredAt ?? this.occurredAt,
      category: category ?? this.category,
      source: source,
      scope: scope ?? this.scope,
      type: type ?? this.type,
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
      reviewed: reviewed ?? this.reviewed,
      parser: parser ?? this.parser,
      parserVersion: parserVersion ?? this.parserVersion,
      notificationHash: notificationHash ?? this.notificationHash,
      rawNotificationId: rawNotificationId ?? this.rawNotificationId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        amount,
        currency,
        merchant,
        occurredAt,
        category,
        source,
        scope,
        type,
        confidence,
        rawText,
        reviewed,
        parser,
        parserVersion,
        notificationHash,
        rawNotificationId,
      ];
}

class CategoryTotal extends Equatable {
  const CategoryTotal({
    required this.category,
    required this.total,
    required this.share,
  });

  final Category category;
  final double total;

  /// Proporción sobre el gasto del mes, entre 0 y 1.
  final double share;

  @override
  List<Object?> get props => [category, total, share];
}

class MonthlySummary extends Equatable {
  const MonthlySummary({
    required this.month,
    required this.total,
    required this.incomeTotal,
    required this.previousMonthTotal,
    required this.byCategory,
    required this.dailyAverage,
  });

  final DateTime month;

  /// Total de gastos del mes.
  final double total;

  /// Total de ingresos del mes.
  final double incomeTotal;

  /// Total de gastos del mes anterior.
  final double previousMonthTotal;

  final List<CategoryTotal> byCategory;
  final double dailyAverage;

  /// Balance neto: Ingresos - Gastos.
  double get netBalance => incomeTotal - total;

  /// Días totales en el mes seleccionado.
  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  /// Días transcurridos en el mes.
  int get daysElapsed {
    final now = DateTime.now();
    final isCurrentMonth = now.year == month.year && now.month == month.month;
    if (isCurrentMonth) return now.day;
    if (DateTime(month.year, month.month)
        .isAfter(DateTime(now.year, now.month))) {
      return 0;
    }
    return daysInMonth;
  }

  /// Días restantes en el mes (para cálculo de presupuesto diario).
  int get daysRemaining {
    final now = DateTime.now();
    final isCurrentMonth = now.year == month.year && now.month == month.month;
    if (isCurrentMonth) {
      final rem = daysInMonth - now.day + 1;
      return rem < 1 ? 1 : rem;
    }
    if (DateTime(month.year, month.month)
        .isAfter(DateTime(now.year, now.month))) {
      return daysInMonth;
    }
    return 0;
  }

  /// Presupuesto diario recomendado para los días restantes del mes.
  /// Si el balance neto es positivo y quedan días, se divide equitativamente.
  double get recommendedDailyBudget {
    if (netBalance <= 0 || daysRemaining <= 0) return 0;
    return netBalance / daysRemaining;
  }

  /// Proporción del ingreso mensual consumido por los gastos (0.0 a 1.0+).
  double get expenseRatio {
    if (incomeTotal <= 0) return total > 0 ? 1.0 : 0.0;
    return total / incomeTotal;
  }

  /// Variación de gastos contra el mes anterior. Negativo = gastaste menos.
  double? get variation {
    if (previousMonthTotal == 0) return null;
    return (total - previousMonthTotal) / previousMonthTotal;
  }

  /// Diferencia monetaria absoluta de gastos respecto al mes anterior.
  double get absoluteVariation => total - previousMonthTotal;

  @override
  List<Object?> get props => [
        month,
        total,
        incomeTotal,
        previousMonthTotal,
        byCategory,
        dailyAverage,
      ];
}
