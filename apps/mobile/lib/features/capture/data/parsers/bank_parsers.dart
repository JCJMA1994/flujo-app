import '../../../transactions/domain/entities/transaction.dart';
import '../../domain/entities/parsed_expense.dart';

/// Un parser por banco. Los formatos de notificación son estables y
/// específicos, así que una regex resuelve la mayoría de casos sin latencia
/// ni costo de IA. El LLM queda como fallback para lo que no encaja.
abstract class BankParser {
  String get bankId;

  String get version => '1.0.0';

  /// Paquetes de Android cuyas notificaciones pertenecen a este banco.
  Set<String> get packageNames;

  bool canHandle(RawNotification notification);

  ParsedExpense? parse(RawNotification notification);
}

/// Utilidades compartidas de normalización.
mixin AmountParsing {
  String get version => '1.0.0';

  /// Acepta "S/ 24.50", "S/. 24.50", "S/24.50", "S/.24.50", "S/ 1,234.56", "PEN 24.50", "US$ 12.00", "$ 10.00", "20 soles".
  static final _amountPattern = RegExp(
    r'(?:(?:S/\.?|PEN|US\$|USD|\$)\s?([\d,]+(?:\.\d{1,2})?)|([\d,]+(?:\.\d{1,2})?)\s?(?:soles|sol|pen|dólares|dolares|usd))',
    caseSensitive: false,
  );

  (double amount, String currency)? extractAmount(String text) {
    final match = _amountPattern.firstMatch(text);
    if (match == null) return null;

    final raw = (match.group(1) ?? match.group(2))!.replaceAll(',', '');
    final value = double.tryParse(raw);
    if (value == null) return null;

    final isUsd = text.toUpperCase().contains(r'US$') ||
        text.toUpperCase().contains('USD') ||
        text.toLowerCase().contains('dólar') ||
        text.toLowerCase().contains('dolar');

    final currency = isUsd ? 'USD' : 'PEN';

    return (value, currency);
  }

  /// Limpia el nombre del comercio o persona: quita prefijos de alerta,
  /// códigos de terminal, espacios múltiples y signos de puntuación sobrantes.
  String cleanMerchant(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'^(?:DLC\*|PAYU\*|IZI\*|CULQI\*|NIUBIZ\*)+',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\*+\d+'), '')
        .replaceAll(
          RegExp(
            r'^(?:[¡!¿?\s]|confirmaci[oó]n\s+de\s+pago!?|te\s+acaban\s+de\s+yapear!?|acaban\s+de\s+yapear!?|te\s+yapearon!?|yapeaste!?|recibiste\s+un\s+yape!?|recibiste\s+un\s+plin!?|enviaste\s+un\s+plin!?|interbank|bbva|bcp|scotiabank|banbif|plin|yape)+\s*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            '[¡!¿?*]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[.,;:\s]+|[.,;:\s]+$'), '')
        .trim();
  }
}

/// Parser especializado en Yape (BCP), que procesa tanto salidas como entradas.
class YapeParser with AmountParsing implements BankParser {
  @override
  String get bankId => 'yape';

  @override
  Set<String> get packageNames => {
        'com.bcp.innovacxion.yapeapp',
        'pe.com.bcp.innovacxion.yapeapp',
        'com.bcp.yape',
      };

  static final _incomingTeEnvio = RegExp(
    r'(?:(?:te\s+acaban\s+de\s+yapear!?|acaban\s+de\s+yapear!?|te\s+yapearon!?|confirmaci[oó]n\s+de\s+pago!?)\s+)?(.+?)\s+te\s+envi[oó]\s+(?:un\s+(?:yape|pago)\s+(?:de|por)\s+)?(?:S/\.?|US\$|PEN|\$)?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _incomingRecibiste = RegExp(
    r'(?:recibiste|te\s+enviaron|te\s+yapearon)\s+(?:un\s+(?:yape|pago)\s+(?:de|por)\s+)?(?:S/\.?|US\$|PEN|\$)?\s?([\d,]+(?:\.\d{1,2})?)(?:\s+(?:de|desde)\s+(.+?))?(?:\.|$)',
    caseSensitive: false,
  );

  static final _outgoingEnviaste = RegExp(
    r'(?:yapeaste!?|enviaste\s+un\s+yape|enviaste|pagaste).*?(?:S/\.?|US\$|PEN|\$)?\s?([\d,]+(?:\.\d{1,2})?)\s+a\s+(.+?)(?:\.|\(|$)',
    caseSensitive: false,
  );

  @override
  bool canHandle(RawNotification n) {
    final pkg = n.packageName.toLowerCase();
    final text = n.fullText.toLowerCase();
    return packageNames.contains(n.packageName) ||
        pkg.contains('yape') ||
        text.contains('yape') ||
        text.contains('confirmación de pago') ||
        text.contains('confirmacion de pago') ||
        text.contains('cód. de seguridad') ||
        text.contains('cod. de seguridad');
  }

  @override
  ParsedExpense? parse(RawNotification n) {
    final text = n.fullText;
    final amount = extractAmount(text);
    if (amount == null) return null;

    // 1. Probar patrones de ingreso
    final inMatch1 = _incomingTeEnvio.firstMatch(text);
    if (inMatch1 != null) {
      final sender = cleanMerchant(inMatch1.group(1)!);
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: sender.isNotEmpty ? sender : 'Transferencia Yape',
        occurredAt: n.receivedAt,
        type: TransactionType.income,
        confidence: 1,
        rawText: text,
        bankId: bankId,
        suggestedCategoryId: 'other_income',
      );
    }

    final inMatch2 = _incomingRecibiste.firstMatch(text);
    if (inMatch2 != null) {
      final rawSender = inMatch2.group(2);
      final sender = rawSender != null ? cleanMerchant(rawSender) : '';
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: sender.isNotEmpty ? sender : 'Transferencia Yape',
        occurredAt: n.receivedAt,
        type: TransactionType.income,
        confidence: 1,
        rawText: text,
        bankId: bankId,
        suggestedCategoryId: 'other_income',
      );
    }

    // 2. Probar patrones de gasto/salida
    final outMatch = _outgoingEnviaste.firstMatch(text);
    if (outMatch != null) {
      final rawRecipient = outMatch.group(2);
      final recipient = rawRecipient != null ? cleanMerchant(rawRecipient) : '';
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: recipient.isNotEmpty ? recipient : 'Pago Yape',
        occurredAt: n.receivedAt,
        confidence: 1,
        rawText: text,
        bankId: bankId,
      );
    }

    // 3. Fallback inteligente por palabras clave
    final lower = text.toLowerCase();
    final isIncome = lower.contains('te yapearon') ||
        lower.contains('recibiste') ||
        lower.contains('te envió') ||
        lower.contains('te envio');

    return ParsedExpense(
      amount: amount.$1,
      currency: amount.$2,
      merchant: isIncome ? 'Ingreso Yape' : 'Gasto Yape',
      occurredAt: n.receivedAt,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      confidence: 0.95,
      rawText: text,
      bankId: bankId,
      suggestedCategoryId: isIncome ? 'other_income' : null,
    );
  }
}

/// Parser especializado en Plin (Interbank, BBVA, Scotiabank, BanBif).
class PlinParser with AmountParsing implements BankParser {
  @override
  String get bankId => 'plin';

  @override
  Set<String> get packageNames => {
        'pe.plin.app',
      };

  static final _incomingTePlineo = RegExp(
    r'(?:(?:interbank|bbva|scotiabank|banbif)\s+)?(.+?)\s+te\s+(?:ha\s+)?pline(?:ado|aron|aste|[oó])\s+(?:S/\.?|US\$|PEN|\$)?\s?([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  static final _incomingTeEnvio = RegExp(
    r'(?:recibiste\s+un\s+plin!?\s+)?(.+?)\s+te\s+envi[oó]\s+(?:un\s+(?:plin|pago)\s+(?:de|por)\s+)?(?:S/\.?|US\$|PEN|\$)?\s?([\d,]+\.?\d{0,2})',
    caseSensitive: false,
  );

  static final _incomingDe = RegExp(
    r'(?:recibiste|te\s+plinearon|te\s+ha\s+plineado).*?(?:de\s+|un\s+plin\s+de\s+)?(?:S/\.?|US\$|PEN|\$)?\s?[\d,]+\.?\d{0,2}\s+de\s+(.+?)(?:\.|$)',
    caseSensitive: false,
  );

  static final _outgoingPattern = RegExp(
    r'(?:enviaste|plineaste|transferencia\s+plin).*?(?:por\s+|un\s+plin\s+de\s+)?(?:S/\.?|US\$|PEN|\$)?\s?[\d,]+\.?\d{0,2}\s+a\s+(.+?)(?:\.|$)',
    caseSensitive: false,
  );

  @override
  bool canHandle(RawNotification n) {
    final pkg = n.packageName.toLowerCase();
    final text = n.fullText.toLowerCase();
    return packageNames.contains(n.packageName) ||
        pkg.contains('plin') ||
        text.contains('plin') ||
        text.contains('pline') ||
        text.contains('plineado') ||
        text.contains('plineaste');
  }

  @override
  ParsedExpense? parse(RawNotification n) {
    final text = n.fullText;
    final amount = extractAmount(text);
    if (amount == null) return null;

    final isIncome = text.toLowerCase().contains('recibiste') ||
        text.toLowerCase().contains('te plinearon') ||
        text.toLowerCase().contains('te ha plineado') ||
        text.toLowerCase().contains('plineado') ||
        text.toLowerCase().contains('te envió') ||
        text.toLowerCase().contains('te envio');

    if (isIncome) {
      final match0 = _incomingTePlineo.firstMatch(text);
      if (match0 != null) {
        final sender = cleanMerchant(match0.group(1)!);
        return ParsedExpense(
          amount: amount.$1,
          currency: amount.$2,
          merchant: sender.isNotEmpty ? sender : 'Transferencia Plin',
          occurredAt: n.receivedAt,
          type: TransactionType.income,
          confidence: 1,
          rawText: text,
          bankId: bankId,
          suggestedCategoryId: 'other_income',
        );
      }

      final match1 = _incomingTeEnvio.firstMatch(text);
      if (match1 != null) {
        final sender = cleanMerchant(match1.group(1)!);
        return ParsedExpense(
          amount: amount.$1,
          currency: amount.$2,
          merchant: sender.isNotEmpty ? sender : 'Transferencia Plin',
          occurredAt: n.receivedAt,
          type: TransactionType.income,
          confidence: 1,
          rawText: text,
          bankId: bankId,
          suggestedCategoryId: 'other_income',
        );
      }

      final match2 = _incomingDe.firstMatch(text);
      final sender = match2 != null
          ? cleanMerchant(match2.group(1)!)
          : 'Transferencia Plin';
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: sender.isNotEmpty ? sender : 'Transferencia Plin',
        occurredAt: n.receivedAt,
        type: TransactionType.income,
        confidence: 1,
        rawText: text,
        bankId: bankId,
        suggestedCategoryId: 'other_income',
      );
    } else {
      final match = _outgoingPattern.firstMatch(text);
      final recipient =
          match != null ? cleanMerchant(match.group(1)!) : 'Pago Plin';
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: recipient.isNotEmpty ? recipient : 'Pago Plin',
        occurredAt: n.receivedAt,
        confidence: 1,
        rawText: text,
        bankId: bankId,
      );
    }
  }
}

class BcpParser with AmountParsing implements BankParser {
  @override
  String get bankId => 'bcp';

  @override
  Set<String> get packageNames => {'pe.com.bcp.bank.bcp'};

  static final _posPattern = RegExp(
    r'consumo\s+de\s+(S/|US\$|PEN|\$)\s?([\d,]+\.?\d{0,2})\s+en\s+(.+?)(?:\s+el\s|\.|$)',
    caseSensitive: false,
  );

  static final _transferOutPattern = RegExp(
    r'transferencia\s+(?:por\s+)?(S/|US\$|PEN|\$)\s?([\d,]+\.?\d{0,2})\s+a\s+(.+?)(?:\s+realizada|\.|$)',
    caseSensitive: false,
  );

  static final _transferInPattern = RegExp(
    r'recibiste\s+una\s+transferencia\s+de\s+(S/|US\$|PEN|\$)\s?([\d,]+\.?\d{0,2})\s+de\s+(.+?)(?:\.|$)',
    caseSensitive: false,
  );

  @override
  bool canHandle(RawNotification n) =>
      packageNames.contains(n.packageName) ||
      (n.fullText.toLowerCase().contains('bcp') &&
          !n.fullText.toLowerCase().contains('yape'));

  @override
  ParsedExpense? parse(RawNotification n) {
    final amount = extractAmount(n.fullText);
    if (amount == null) return null;

    final inMatch = _transferInPattern.firstMatch(n.fullText);
    if (inMatch != null) {
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: cleanMerchant(inMatch.group(3)!),
        occurredAt: n.receivedAt,
        type: TransactionType.income,
        confidence: 1,
        rawText: n.fullText,
        bankId: bankId,
        suggestedCategoryId: 'other_income',
      );
    }

    final posMatch = _posPattern.firstMatch(n.fullText);
    if (posMatch != null) {
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: cleanMerchant(posMatch.group(3)!),
        occurredAt: n.receivedAt,
        confidence: 1,
        rawText: n.fullText,
        bankId: bankId,
      );
    }

    final outMatch = _transferOutPattern.firstMatch(n.fullText);
    if (outMatch != null) {
      return ParsedExpense(
        amount: amount.$1,
        currency: amount.$2,
        merchant: cleanMerchant(outMatch.group(3)!),
        occurredAt: n.receivedAt,
        confidence: 1,
        rawText: n.fullText,
        bankId: bankId,
      );
    }

    return null;
  }
}

class InterbankParser with AmountParsing implements BankParser {
  @override
  String get bankId => 'interbank';

  @override
  Set<String> get packageNames => {
        'pe.interbank.appnew',
        'pe.com.interbank',
      };

  static final _patternAmountBeforeMerchant = RegExp(
    r'(?:se\s+realiz[oó]\s+(?:un\s+)?)?(?:compra|consumo|pago(?:\s+recurrente)?|cargo).*?\s+(?:en|a)\s+(.+?)(?:\s+con\s+tu|\s+el\s+|\.|\(|$)',
    caseSensitive: false,
  );

  static final _patternMerchantBeforeAmount = RegExp(
    r'(?:compra|consumo|pago|cargo)\s+en\s+(.+?)\s+(?:por|de)\s+(?:S/\.?|US\$|PEN|\$)?\s?[\d,]+(?:\.\d{1,2})?',
    caseSensitive: false,
  );

  @override
  bool canHandle(RawNotification n) =>
      packageNames.contains(n.packageName) ||
      n.fullText.toLowerCase().contains('interbank') ||
      n.packageName.contains('interbank');

  @override
  ParsedExpense? parse(RawNotification n) {
    final amount = extractAmount(n.fullText);
    if (amount == null) return null;

    final match1 = _patternAmountBeforeMerchant.firstMatch(n.fullText);
    final match2 = _patternMerchantBeforeAmount.firstMatch(n.fullText);

    final rawMerchant = match1?.group(1) ?? match2?.group(1);
    final merchant =
        rawMerchant != null ? cleanMerchant(rawMerchant) : 'Consumo Interbank';

    return ParsedExpense(
      amount: amount.$1,
      currency: amount.$2,
      merchant: merchant.isNotEmpty ? merchant : 'Consumo Interbank',
      occurredAt: n.receivedAt,
      confidence: 1,
      rawText: n.fullText,
      bankId: bankId,
    );
  }
}

class BbvaParser with AmountParsing implements BankParser {
  @override
  String get bankId => 'bbva';

  @override
  Set<String> get packageNames => {'com.bbva.pe.bbvacontigo'};

  static final _pattern = RegExp(
    r'(?:realizaste|se\s+realiz[oó])\s+(?:un\s+)?(?:consumo|compra|pago).*?\s+en\s+(.+?)(?:\s+por|\.|$)',
    caseSensitive: false,
  );

  @override
  bool canHandle(RawNotification n) =>
      packageNames.contains(n.packageName) ||
      n.fullText.toLowerCase().contains('bbva');

  @override
  ParsedExpense? parse(RawNotification n) {
    final match = _pattern.firstMatch(n.fullText);
    final amount = extractAmount(n.fullText);
    if (match == null || amount == null) return null;

    return ParsedExpense(
      amount: amount.$1,
      currency: amount.$2,
      merchant: cleanMerchant(match.group(1)!),
      occurredAt: n.receivedAt,
      confidence: 1,
      rawText: n.fullText,
      bankId: bankId,
    );
  }
}

/// Último recurso antes del LLM: si hay un monto reconocible, registramos el
/// gasto con confianza baja y dejamos que el usuario complete el comercio.
class GenericAmountParser with AmountParsing implements BankParser {
  @override
  String get bankId => 'generic';

  @override
  Set<String> get packageNames => const {};

  @override
  bool canHandle(RawNotification n) => extractAmount(n.fullText) != null;

  @override
  ParsedExpense? parse(RawNotification n) {
    final amount = extractAmount(n.fullText);
    if (amount == null) return null;

    return ParsedExpense(
      amount: amount.$1,
      currency: amount.$2,
      merchant: n.title.isNotEmpty ? cleanMerchant(n.title) : 'Sin identificar',
      occurredAt: n.receivedAt,
      confidence: 0.4,
      rawText: n.fullText,
    );
  }
}
