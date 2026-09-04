import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/transaction.dart';

/// Servicio para exportar transacciones a formato CSV compatible con Excel y hojas de cálculo.
class TransactionExportService {
  const TransactionExportService();

  /// Genera una cadena CSV con BOM UTF-8 para garantizar que tildes y caracteres especiales
  /// se abran correctamente en Excel.
  String generateCsv(List<Transaction> transactions) {
    final buffer = StringBuffer()
      ..write('\uFEFF')
      ..writeln(
        'Fecha,Hora,Tipo,Comercio / Detalle,Categoría,Monto,Moneda,Ámbito,Origen,Detalle',
      );

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (final tx in transactions) {
      final date = dateFormat.format(tx.occurredAt);
      final time = timeFormat.format(tx.occurredAt);
      final type = tx.type == TransactionType.income ? 'Ingreso' : 'Gasto';
      final merchant = _escapeCsv(tx.merchant);
      final category = _escapeCsv(tx.category.name);
      final amount = tx.amount.toStringAsFixed(2);
      final currency = tx.currency;
      final scope =
          tx.scope == TransactionScope.business ? 'Negocio' : 'Personal';
      final source = tx.source.name;
      final rawDetail = _escapeCsv(tx.rawText ?? '');

      buffer.writeln(
        '$date,$time,$type,$merchant,$category,$amount,$currency,$scope,$source,$rawDetail',
      );
    }

    return buffer.toString();
  }

  String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  Future<File> writeCsvFile({
    required List<Transaction> transactions,
    String? fileName,
  }) async {
    final csvContent = generateCsv(transactions);
    final tempDir = await getTemporaryDirectory();
    final name = fileName ??
        'flujo_transacciones_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    final file = File('${tempDir.path}/$name.csv');
    return file.writeAsString(csvContent);
  }

  Future<void> shareCsv({
    required List<Transaction> transactions,
    String? fileName,
  }) async {
    if (transactions.isEmpty) return;
    final file = await writeCsvFile(
      transactions: transactions,
      fileName: fileName,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Exportación de transacciones - Flujo App',
        text: 'Exportación de transacciones - Flujo App',
      ),
    );
  }
}
