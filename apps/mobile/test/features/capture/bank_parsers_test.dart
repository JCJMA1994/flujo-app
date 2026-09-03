import 'package:flujo/features/capture/data/parsers/bank_parsers.dart';
import 'package:flujo/features/capture/domain/entities/parsed_expense.dart';
import 'package:flujo/features/transactions/domain/entities/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los parsers son lo más valioso de testear: lógica pura, sin dependencias,
/// y un fallo aquí significa gastos perdidos o mal registrados.
void main() {
  RawNotification notification(String package, String title, String body) {
    return RawNotification(
      packageName: package,
      title: title,
      body: body,
      receivedAt: DateTime(2026, 9),
    );
  }

  group('YapeParser', () {
    final parser = YapeParser();

    test('reconoce ingreso cuando alguien te yapea', () {
      final result = parser.parse(
        notification(
          'com.bcp.innovacxion.yapeapp',
          '¡Te yapearon!',
          'Juan Perez te envió S/ 20.00 a tu cuenta.',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 20);
      expect(result.currency, 'PEN');
      expect(result.merchant, 'Juan Perez');
      expect(result.type, TransactionType.income);
      expect(result.confidence, 1);
    });

    test('reconoce ingreso con variante "te acaban de yapear"', () {
      final result = parser.parse(
        notification(
          'com.bcp.innovacxion.yapeapp',
          '¡Te acaban de yapear!',
          'Maria te envió S/ 15.50',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 15.5);
      expect(result.merchant, 'Maria');
      expect(result.type, TransactionType.income);
    });

    test('reconoce gasto cuando tú yapeas a un comercio o persona', () {
      final result = parser.parse(
        notification(
          'com.bcp.innovacxion.yapeapp',
          '¡Yapeaste!',
          'Enviaste S/ 15.00 a Bodega Don Pepe',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 15);
      expect(result.currency, 'PEN');
      expect(result.merchant, 'Bodega Don Pepe');
      expect(result.type, TransactionType.expense);
      expect(result.confidence, 1);
    });

    test('reconoce gasto con variante "Enviaste un Yape de"', () {
      final result = parser.parse(
        notification(
          'com.bcp.innovacxion.yapeapp',
          'Yape',
          'Enviaste un Yape de S/ 30.00 a Carlos Lopez',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 30);
      expect(result.merchant, 'Carlos Lopez');
      expect(result.type, TransactionType.expense);
    });

    test('reconoce ingreso de Yape con formato Confirmación de Pago', () {
      final result = parser.parse(
        notification(
          'com.bcp.innovacxion.yapeapp',
          'Confirmación de Pago',
          'Carlos Cub* te envió un pago por S/ 1. El cód. de seguridad es: 263',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 1);
      expect(result.currency, 'PEN');
      expect(result.merchant, 'Carlos Cub');
      expect(result.type, TransactionType.income);
      expect(result.confidence, 1);
    });
  });

  group('PlinParser', () {
    final parser = PlinParser();

    test('reconoce ingreso de Plin', () {
      final result = parser.parse(
        notification(
          'pe.plin.app',
          '¡Recibiste un Plin!',
          'Pedro te envió S/ 50.00',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 50);
      expect(result.merchant, 'Pedro');
      expect(result.type, TransactionType.income);
    });

    test('reconoce salida de Plin', () {
      final result = parser.parse(
        notification(
          'pe.plin.app',
          '¡Enviaste un Plin!',
          'Enviaste S/ 25.00 a Maria',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 25);
      expect(result.merchant, 'Maria');
      expect(result.type, TransactionType.expense);
    });

    test('reconoce ingreso de Plin cuando te plinean desde Interbank', () {
      final result = parser.parse(
        notification(
          'pe.interbank.appnew',
          'Interbank',
          'Carlos Raul Cubas Estela te ha plineado S/ 1.00',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 1);
      expect(result.currency, 'PEN');
      expect(result.merchant, 'Carlos Raul Cubas Estela');
      expect(result.type, TransactionType.income);
      expect(result.confidence, 1);
    });
  });

  group('BcpParser', () {
    final parser = BcpParser();

    test('extrae monto y comercio de un consumo en soles', () {
      final result = parser.parse(
        notification(
          'pe.com.bcp.bank.bcp',
          'Banco BCP',
          'Consumo de S/24.50 en Starbucks el 01/09.',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 24.50);
      expect(result.currency, 'PEN');
      expect(result.merchant, 'Starbucks');
      expect(result.type, TransactionType.expense);
      expect(result.confidence, 1);
    });

    test('maneja montos con separador de miles', () {
      final result = parser.parse(
        notification(
          'pe.com.bcp.bank.bcp',
          'Banco BCP',
          'Consumo de S/1,234.56 en Wong Miraflores.',
        ),
      );

      expect(result!.amount, 1234.56);
      expect(result.merchant, 'Wong Miraflores');
    });

    test('reconoce dólares', () {
      final result = parser.parse(
        notification(
          'pe.com.bcp.bank.bcp',
          'Banco BCP',
          r'Consumo de US$45.00 en Amazon.',
        ),
      );

      expect(result!.currency, 'USD');
      expect(result.amount, 45);
    });

    test('devuelve null si no hay patrón de consumo', () {
      final result = parser.parse(
        notification(
          'pe.com.bcp.bank.bcp',
          'Banco BCP',
          'Tu clave digital fue actualizada correctamente.',
        ),
      );

      expect(result, isNull);
    });
  });

  group('InterbankParser', () {
    final parser = InterbankParser();

    test('procesa pago recurrente de suscripción como HBO Max', () {
      final result = parser.parse(
        notification(
          'pe.interbank.appnew',
          'Interbank',
          'Se realizó un pago recurrente de S/.11.90 en DLC*helphbomaxcom con tu Tarjeta de Crédito.',
        ),
      );

      expect(result, isNotNull);
      expect(result!.amount, 11.90);
      expect(result.currency, 'PEN');
      expect(result.merchant, 'helphbomaxcom');
      expect(result.type, TransactionType.expense);
      expect(result.confidence, 1);
    });
  });

  group('GenericAmountParser', () {
    final parser = GenericAmountParser();

    test('captura el monto con confianza baja cuando no reconoce el formato',
        () {
      final result = parser.parse(
        notification('pe.banco.desconocido', 'Mi Banco', 'Pagaste S/89.90'),
      );

      expect(result!.amount, 89.90);
      // Confianza baja: entra a la cola de revisión del usuario.
      expect(result.confidence, lessThan(0.7));
    });
  });

  group('limpieza de comercio', () {
    final parser = BcpParser();

    test('quita códigos de terminal del nombre', () {
      expect(parser.cleanMerchant('RAPPI *4821'), 'RAPPI');
      expect(parser.cleanMerchant('  Metro   Lima  '), 'Metro Lima');
      expect(parser.cleanMerchant('Uber Trip.'), 'Uber Trip');
    });
  });

  group('UserRule', () {
    final expense = ParsedExpense(
      amount: 3.50,
      currency: 'PEN',
      merchant: 'Bodega Doña Rosa',
      occurredAt: DateTime(2026, 9),
      confidence: 1,
      rawText: '',
    );

    test('amountBelow aplica a gastos hormiga', () {
      const rule = UserRule(
        id: '1',
        matcher: RuleMatcher.amountBelow,
        value: '5',
        targetCategoryId: 'ants',
      );

      expect(rule.matches(expense), isTrue);
    });

    test('merchantContains es insensible a mayúsculas', () {
      const rule = UserRule(
        id: '2',
        matcher: RuleMatcher.merchantContains,
        value: 'bodega',
        targetCategoryId: 'groceries',
      );

      expect(rule.matches(expense), isTrue);
    });
  });
}
