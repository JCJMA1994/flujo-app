import 'package:flujo/features/transactions/data/services/transaction_export_service.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TransactionExportService exportService;

  setUp(() {
    exportService = const TransactionExportService();
  });

  group('TransactionExportService', () {
    test('generateCsv genera encabezado correcto con BOM UTF-8', () {
      final csv = exportService.generateCsv([]);
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(
        csv.contains(
          'Fecha,Hora,Tipo,Comercio / Detalle,Categoría,Monto,Moneda,Ámbito,Origen,Detalle',
        ),
        isTrue,
      );
    });

    test('generateCsv exporta transacciones de gasto e ingreso correctamente',
        () {
      final txs = [
        Transaction(
          id: 'tx-1',
          amount: 25.50,
          currency: 'PEN',
          merchant: 'Starbucks Larcomar',
          occurredAt: DateTime(2026, 3, 15, 14, 30),
          category: const Category(id: 'food', name: 'Comida', emoji: '🍔'),
          source: TransactionSource.bankNotification,
          scope: TransactionScope.personal,
          rawText: 'Café con amigos',
        ),
        Transaction(
          id: 'tx-2',
          amount: 1500,
          currency: 'PEN',
          merchant: 'Cliente ABC, S.A.C.',
          occurredAt: DateTime(2026, 3, 16, 9, 15),
          category:
              const Category(id: 'freelance', name: 'Honorarios', emoji: '💼'),
          source: TransactionSource.manual,
          scope: TransactionScope.business,
          type: TransactionType.income,
          rawText: 'Servicio de desarrollo',
        ),
      ];

      final csv = exportService.generateCsv(txs);

      // Verificamos formato del gasto
      expect(
        csv.contains(
          '2026-03-15,14:30:00,Gasto,Starbucks Larcomar,Comida,25.50,PEN,Personal,bankNotification,Café con amigos',
        ),
        isTrue,
      );

      // Verificamos escape de comas en el comercio del ingreso ("Cliente ABC, S.A.C.")
      expect(
        csv.contains(
          '2026-03-16,09:15:00,Ingreso,"Cliente ABC, S.A.C.",Honorarios,1500.00,PEN,Negocio,manual,Servicio de desarrollo',
        ),
        isTrue,
      );
    });

    test('generateCsv escapa comillas dobles en campos de texto', () {
      final tx = Transaction(
        id: 'tx-3',
        amount: 50,
        currency: 'PEN',
        merchant: 'Bodega "Don Pepe"',
        occurredAt: DateTime(2026, 3, 17, 18),
        category:
            const Category(id: 'groceries', name: 'Supermercado', emoji: '🛒'),
        source: TransactionSource.manual,
        scope: TransactionScope.personal,
      );

      final csv = exportService.generateCsv([tx]);
      expect(csv.contains('"Bodega ""Don Pepe"""'), isTrue);
    });
  });
}
