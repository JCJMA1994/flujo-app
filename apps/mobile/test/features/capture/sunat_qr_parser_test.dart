import 'package:flujo/features/capture/domain/services/sunat_qr_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SunatQrParser parser;

  setUp(() {
    parser = const SunatQrParser();
  });

  group('SunatQrParser', () {
    test('interpreta correctamente QR de Boleta SUNAT delimitada por pipes',
        () {
      const rawQr =
          '20100070970|03|B001|00004523|5.40|35.40|2026-09-04|1|45678901|d41d8cd98f00b204e9800998ecf8427e|';

      final result = parser.parse(rawQr);

      expect(result, isNotNull);
      expect(result!.ruc, equals('20100070970'));
      expect(result.documentType, equals('Boleta de Venta Electrónica'));
      expect(result.serialNumber, equals('B001-00004523'));
      expect(result.taxAmount, equals(5.40));
      expect(result.totalAmount, equals(35.40));
      expect(result.merchantSuggested, contains('Plaza Vea'));
      expect(result.suggestedCategory.id, equals('groceries'));
      expect(result.date, equals(DateTime(2026, 9, 4)));
      expect(result.customerDocumentType, equals('DNI'));
      expect(result.customerDocumentNumber, equals('45678901'));
      expect(result.digitalHash, equals('d41d8cd98f00b204e9800998ecf8427e'));
    });

    test('interpreta Boleta SUNAT Huawei con DNI del cliente y firma digital', () {
      const rawQr =
          '20507646728|03|BE01|00088698|45.61|299.00|2025-09-10|1|71542895|8NDCcEtzxHo41A6QhQj2eNJUggs=|';

      final result = parser.parse(rawQr);

      expect(result, isNotNull);
      expect(result!.ruc, equals('20507646728'));
      expect(result.documentType, equals('Boleta de Venta Electrónica'));
      expect(result.serialNumber, equals('BE01-00088698'));
      expect(result.taxAmount, equals(45.61));
      expect(result.totalAmount, equals(299.00));
      expect(result.merchantSuggested, equals('Huawei del Perú'));
      expect(result.suggestedCategory.id, equals('shopping'));
      expect(result.date, equals(DateTime(2025, 9, 10)));
      expect(result.customerDocumentType, equals('DNI'));
      expect(result.customerDocumentNumber, equals('71542895'));
      expect(result.digitalHash, equals('8NDCcEtzxHo41A6QhQj2eNJUggs='));
    });

    test('interpreta Factura SUNAT de farmacia (Inkafarma/Mifarma)', () {
      const rawQr =
          '20100055237|01|F002|00129841|15.25|100.00|2026-09-01|6|20512345678|hashcode|';

      final result = parser.parse(rawQr);

      expect(result, isNotNull);
      expect(result!.documentType, equals('Factura Electrónica'));
      expect(result.totalAmount, equals(100.00));
      expect(result.merchantSuggested, contains('MiFarma'));
      expect(result.suggestedCategory.id, equals('health'));
    });

    test('interpreta QR con URL que incluye parámetros query', () {
      const rawUrl =
          'https://cpe.facturalo.pe/consulta?ruc=20543130776&tipo=03&serie=B012&numero=4492&total=18.50&fecha=2026-09-03';

      final result = parser.parse(rawUrl);

      expect(result, isNotNull);
      expect(result!.totalAmount, equals(18.50));
      expect(result.merchantSuggested, contains('Tambo'));
      expect(result.suggestedCategory.id, equals('food'));
    });

    test('retorna null ante texto vacío o no relacionado', () {
      expect(parser.parse(''), isNull);
      expect(parser.parse('hola mundo'), isNull);
      expect(parser.parse('https://google.com'), isNull);
    });
  });
}
