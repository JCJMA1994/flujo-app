import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Tabla de transacciones. Guardamos `rawText` siempre: cuando el parser
/// mejore vamos a querer reprocesar el histórico sin haber perdido el original.
class TransactionsTable extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withLength(min: 3, max: 3)();
  TextColumn get merchant => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get categoryId => text()();
  TextColumn get source => text()();
  TextColumn get scope => text().withDefault(const Constant('personal'))();
  TextColumn get type => text().withDefault(const Constant('expense'))();
  RealColumn get confidence => real().withDefault(const Constant(1))();
  BoolColumn get reviewed => boolean().withDefault(const Constant(true))();
  TextColumn get rawText => text().nullable()();

  /// Null = creada o editada offline, pendiente de confirmar con el servidor.
  DateTimeColumn get syncedAt => dateTime().nullable()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Metadatos de parser, versión y trazabilidad
  TextColumn get parser => text().nullable()();
  TextColumn get parserVersion => text().nullable()();
  TextColumn get notificationHash => text().nullable()();
  TextColumn get rawNotificationId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text().withDefault(const Constant('💸'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Reglas que el usuario le enseña a la app.
/// Ejemplo: "los gastos menores a 5 soles van a Gastos Hormiga".
class UserRulesTable extends Table {
  @override
  String get tableName => 'user_rules';

  TextColumn get id => text()();

  /// 'merchant_contains' | 'amount_below' | 'amount_above'
  TextColumn get matcher => text()();
  TextColumn get matcherValue => text()();
  TextColumn get targetCategoryId => text()();
  TextColumn get targetScope => text().nullable()();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Registro inmutable de notificaciones crudas para auditoría, trazabilidad y reprocesamiento.
class RawEventsTable extends Table {
  @override
  String get tableName => 'raw_events';

  TextColumn get id => text()();
  TextColumn get notificationKey => text().nullable()();
  TextColumn get notificationHash => text().unique()();
  TextColumn get packageName => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('PROCESSED'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    TransactionsTable,
    CategoriesTable,
    UserRulesTable,
    RawEventsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'flujo'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(transactionsTable, transactionsTable.type);
            await _seedCategories();
          }
          if (from < 3) {
            await m.createTable(rawEventsTable);
            await m.addColumn(transactionsTable, transactionsTable.parser);
            await m.addColumn(
              transactionsTable,
              transactionsTable.parserVersion,
            );
            await m.addColumn(
              transactionsTable,
              transactionsTable.notificationHash,
            );
            await m.addColumn(
              transactionsTable,
              transactionsTable.rawNotificationId,
            );
          }
        },
        beforeOpen: (details) async {
          // Necesario para que ON DELETE CASCADE funcione en SQLite.
          await customStatement('PRAGMA foreign_keys = ON');
          await _seedCategories();
        },
      );

  Future<void> _seedCategories() async {
    const seed = [
      ('food', 'Comida', '🍔'),
      ('transport', 'Transporte', '🚕'),
      ('delivery', 'Delivery', '🛵'),
      ('groceries', 'Supermercado', '🛒'),
      ('services', 'Servicios', '💡'),
      ('health', 'Salud', '💊'),
      ('shopping', 'Compras', '🛍️'),
      ('subscriptions', 'Suscripciones', '📺'),
      ('ants', 'Gastos hormiga', '🐜'),
      ('salary', 'Sueldo', '💰'),
      ('freelance', 'Honorarios / Ventas', '💼'),
      ('investments', 'Inversiones', '📈'),
      ('gifts', 'Regalos / Premios', '🎁'),
      ('other_income', 'Otros ingresos', '💵'),
      ('other', 'Otros', '💸'),
    ];

    await batch((b) {
      for (final c in seed) {
        b.insert(
          categoriesTable,
          CategoriesTableCompanion.insert(
            id: c.$1,
            name: c.$2,
            emoji: Value(c.$3),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
