import '../../../transactions/domain/entities/transaction.dart';

/// Datos extraídos y estructurados a partir de un código QR de boleta o factura SUNAT.
class SunatReceiptData {
  const SunatReceiptData({
    required this.ruc,
    required this.documentType,
    required this.serialNumber,
    required this.totalAmount,
    required this.merchantSuggested,
    required this.suggestedCategory,
    this.date,
    this.taxAmount,
    this.rawContent = '',
  });

  final String ruc;
  final String documentType;
  final String serialNumber;
  final double totalAmount;
  final String merchantSuggested;
  final Category suggestedCategory;
  final DateTime? date;
  final double? taxAmount;
  final String rawContent;
}

/// Parser especializado en códigos QR de Comprobantes de Pago Electrónicos (CPE) de SUNAT (Perú).
/// Soporta formato estándar con delimitador pipe (`|`), separador guión (`-`) y enlaces URL con parámetros.
class SunatQrParser {
  const SunatQrParser();

  static Category _category(String id) => kExpenseCategories.firstWhere(
        (c) => c.id == id,
        orElse: () => kExpenseCategories.last,
      );

  static final Map<String, (String merchant, Category category)> _knownRucs = {
    '20100070970': (
      'Supermercados Peruanos (Plaza Vea/Vivanda)',
      _category('groceries')
    ),
    '20100107211': ('Cencosud (Wong/Metro)', _category('groceries')),
    '20543130776': ('Tiendas Tambo', _category('food')),
    '20601446756': ('Tiendas Oxxo', _category('food')),
    '20100055237': ('InkaFarma / MiFarma', _category('health')),
    '20100128056': ('Estaciones Primax', _category('transport')),
    '20100017491': ('Estaciones Repsol', _category('transport')),
    '20100010721': ('Saga Falabella', _category('shopping')),
    '20100128218': ('Tiendas Ripley', _category('shopping')),
    '20508565934': ('Sodimac / Maestro Perú', _category('services')),
    '20100026211': ('Tottus', _category('groceries')),
    '20370146994': ('Bembos / NGR', _category('food')),
  };

  /// Intenta interpretar un texto escaneado de un código QR.
  /// Retorna [SunatReceiptData] si el formato coincide con un comprobante SUNAT, o `null` si no es reconocido.
  SunatReceiptData? parse(String rawText) {
    final clean = rawText.trim();
    if (clean.isEmpty) return null;

    // 1. Formato estándar SUNAT delimitado por pipes (|)
    // Ejemplo: 20100070970|03|B001|00004523|5.40|35.40|2026-09-04|1|45678901|d41d8cd98f00b204...
    if (clean.contains('|')) {
      final parts = clean.split('|');
      if (parts.length >= 6) {
        final ruc = parts[0].trim();
        final tipoDoc = parts[1].trim();
        final serie = parts[2].trim();
        final numero = parts[3].trim();
        final igvStr = parts[4].trim();
        final totalStr = parts[5].trim();
        final fechaStr = parts.length > 6 ? parts[6].trim() : '';

        final total = double.tryParse(totalStr.replaceAll(',', ''));
        if (total != null && total > 0) {
          final igv = double.tryParse(igvStr.replaceAll(',', ''));
          final docName = _resolveDocumentName(tipoDoc);
          final date = _parseDate(fechaStr);
          final known = _knownRucs[ruc];

          final merchant = known?.$1 ??
              (ruc.isNotEmpty
                  ? 'Comercio RUC $ruc'
                  : 'Pago en Efectivo (Boleta)');
          final category = known?.$2 ?? _category('other');

          return SunatReceiptData(
            ruc: ruc,
            documentType: docName,
            serialNumber: '$serie-$numero',
            totalAmount: total,
            taxAmount: igv,
            date: date,
            merchantSuggested: merchant,
            suggestedCategory: category,
            rawContent: clean,
          );
        }
      }
    }

    // 2. Formato URL con parámetros (ej: https://.../cpe?ruc=20100...&tipo=03&total=50.00)
    final uri = Uri.tryParse(clean);
    if (uri != null && uri.hasQuery) {
      final params = uri.queryParameters;
      final totalStr = params['total'] ??
          params['monto'] ??
          params['importe'] ??
          params['totalAmount'];
      final ruc = params['ruc'] ?? params['emisor'] ?? '';

      if (totalStr != null) {
        final total = double.tryParse(totalStr.replaceAll(',', ''));
        if (total != null && total > 0) {
          final tipoDoc = params['tipo'] ?? params['tipoDoc'] ?? '03';
          final serie = params['serie'] ?? '';
          final numero = params['numero'] ?? params['correlativo'] ?? '';
          final fechaStr = params['fecha'] ?? '';

          final known = _knownRucs[ruc];
          return SunatReceiptData(
            ruc: ruc,
            documentType: _resolveDocumentName(tipoDoc),
            serialNumber: '$serie${serie.isNotEmpty ? '-' : ''}$numero',
            totalAmount: total,
            date: _parseDate(fechaStr),
            merchantSuggested: known?.$1 ??
                (ruc.isNotEmpty ? 'Comercio RUC $ruc' : 'Comprobante SUNAT'),
            suggestedCategory: known?.$2 ?? _category('other'),
            rawContent: clean,
          );
        }
      }
    }

    // 3. Formato delimitado por guiones o espacios si contiene RUC de 11 dígitos y monto
    final rucRegex = RegExp(r'\b(10|20)\d{9}\b');
    final rucMatch = rucRegex.firstMatch(clean);
    final amountRegex = RegExp(r'\b(?:S\/?\.?\s*)?(\d+(?:\.\d{1,2}))\b');
    final amountMatch = amountRegex.firstMatch(clean);

    if (rucMatch != null && amountMatch != null) {
      final ruc = rucMatch.group(0)!;
      final total = double.tryParse(amountMatch.group(1)!);
      if (total != null && total > 0) {
        final known = _knownRucs[ruc];
        return SunatReceiptData(
          ruc: ruc,
          documentType: 'Comprobante SUNAT',
          serialNumber: '',
          totalAmount: total,
          merchantSuggested: known?.$1 ?? 'Comercio RUC $ruc',
          suggestedCategory: known?.$2 ?? _category('other'),
          date: DateTime.now(),
          rawContent: clean,
        );
      }
    }

    return null;
  }

  String _resolveDocumentName(String code) {
    return switch (code) {
      '01' => 'Factura Electrónica',
      '03' => 'Boleta de Venta Electrónica',
      '07' => 'Nota de Crédito',
      '08' => 'Nota de Débito',
      _ => 'Comprobante Electrónico',
    };
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      // YYYY-MM-DD
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          return DateTime(y, m, d);
        }
      }
      // DD/MM/YYYY
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final d = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final y = int.parse(parts[2]);
          return DateTime(y, m, d);
        }
      }
    } catch (_) {}
    return null;
  }
}
