import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';
import 'transaction_local_datasource.dart';

/// Traduce el `TransactionFilter` del dominio a SQL. Toda la lógica de
/// consulta vive aquí: el repositorio no sabe que existe una base de datos.
class DriftTransactionLocalDataSource implements TransactionLocalDataSource {
  DriftTransactionLocalDataSource(this._db);

  final AppDatabase _db;

  @override
  Stream<List<TransactionModel>> watchTransactions(TransactionFilter filter) {
    final query = _db.select(_db.transactionsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.transactionsTable.categoryId),
      ),
    ])
      ..where(_db.transactionsTable.deleted.equals(false));

    if (filter.month case final month?) {
      final start = DateTime(month.year, month.month);
      final end = DateTime(month.year, month.month + 1);
      query.where(
        _db.transactionsTable.occurredAt.isBetweenValues(start, end),
      );
    }

    if (filter.categoryIds.isNotEmpty) {
      query.where(_db.transactionsTable.categoryId.isIn(filter.categoryIds));
    }

    if (filter.scope case final scope?) {
      query.where(_db.transactionsTable.scope.equals(scope.name));
    }

    if (filter.type case final type?) {
      query.where(_db.transactionsTable.type.equals(type.name));
    }

    if (filter.parser case final parser?) {
      query.where(_db.transactionsTable.parser.equals(parser));
    }

    if (filter.onlyNeedsReview) {
      query.where(
        _db.transactionsTable.reviewed.equals(false) |
            _db.transactionsTable.confidence.isSmallerThanValue(0.7),
      );
    }

    if (filter.query.isNotEmpty) {
      // `like` con collation NOCASE evita depender de LOWER() por fila.
      query.where(
        _db.transactionsTable.merchant.like('%${filter.query}%'),
      );
    }

    query.orderBy([
      OrderingTerm.desc(_db.transactionsTable.occurredAt),
      OrderingTerm.desc(_db.transactionsTable.id),
    ]);

    // `watch()` reemite automáticamente cuando cambian las tablas implicadas.
    return query.watch().map(
          (rows) => rows.map(_mapRow).toList(),
        );
  }

  TransactionModel _mapRow(TypedResult row) {
    final tx = row.readTable(_db.transactionsTable);
    final category = row.readTableOrNull(_db.categoriesTable);

    final fallback = kDefaultCategories.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => const Category(id: 'other', name: 'Otros', emoji: '💸'),
    );

    return TransactionModel(
      id: tx.id,
      amount: tx.amount,
      currency: tx.currency,
      merchant: tx.merchant,
      occurredAt: tx.occurredAt,
      categoryId: category?.id ?? fallback.id,
      categoryName: category?.name ?? fallback.name,
      categoryEmoji: category?.emoji ?? fallback.emoji,
      source: tx.source,
      scope: tx.scope,
      type: tx.type,
      confidence: tx.confidence,
      reviewed: tx.reviewed,
      rawText: tx.rawText,
      syncedAt: tx.syncedAt,
      parser: tx.parser,
      parserVersion: tx.parserVersion,
      notificationHash: tx.notificationHash,
      rawNotificationId: tx.rawNotificationId,
    );
  }

  @override
  Future<TransactionModel> upsert(TransactionModel model) async {
    await _db.into(_db.transactionsTable).insertOnConflictUpdate(
          TransactionsTableCompanion.insert(
            id: model.id,
            amount: model.amount,
            currency: model.currency,
            merchant: model.merchant,
            occurredAt: model.occurredAt,
            categoryId: model.categoryId,
            source: model.source,
            scope: Value(model.scope),
            type: Value(model.type),
            confidence: Value(model.confidence),
            reviewed: Value(model.reviewed),
            rawText: Value(model.rawText),
            parser: Value(model.parser),
            parserVersion: Value(model.parserVersion),
            notificationHash: Value(model.notificationHash),
            rawNotificationId: Value(model.rawNotificationId),
            // Marcamos como pendiente: cualquier escritura local necesita subir.
            syncedAt: const Value(null),
          ),
        );
    return model;
  }

  @override
  Future<TransactionModel?> getTransaction(String id) async {
    final query = _db.select(_db.transactionsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.transactionsTable.categoryId),
      ),
    ])
      ..where(_db.transactionsTable.id.equals(id))
      ..where(_db.transactionsTable.deleted.equals(false));

    final row = await query.getSingleOrNull();
    return row != null ? _mapRow(row) : null;
  }

  @override
  Future<void> delete(String id) async {
    // Borrado lógico: si borráramos la fila, la sincronización no tendría
    // forma de comunicarle el borrado al servidor.
    await (_db.update(_db.transactionsTable)..where((t) => t.id.equals(id)))
        .write(
      const TransactionsTableCompanion(
        deleted: Value(true),
        syncedAt: Value(null),
      ),
    );
  }

  @override
  Future<List<TransactionModel>> pendingSync() async {
    final query = _db.select(_db.transactionsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.transactionsTable.categoryId),
      ),
    ])
      ..where(_db.transactionsTable.syncedAt.isNull());

    final rows = await query.get();
    return rows.map(_mapRow).toList();
  }

  @override
  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.update(_db.transactionsTable)..where((t) => t.id.isIn(ids)))
        .write(TransactionsTableCompanion(syncedAt: Value(DateTime.now())));
  }
}
