import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';

enum SyncOperationType {
  createCustomer,
  createCustomerAddress,
  createRental,
  addReturn,
  addRate,
  changeInvoicePreference,
  createBillingPeriod,
  updateBillingPeriod,
  createSale,
  createStockCount,
  createOpeningStock,
  createPurchase,
  uploadDocumentMetadata,
}

class PendingSyncOperation {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final DateTime? nextAttemptAt;

  const PendingSyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.nextAttemptAt,
  });
}

class OfflineSyncService {
  OfflineSyncService({AppDatabase? db})
      : db = db ?? AppDatabase.instance;

  final AppDatabase db;
  final _uuid = const Uuid();

  Future<List<PendingSyncOperation>> list() async {
    final rows = await (db.select(db.pendingOperations)
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();

    return rows.map((row) {
      return PendingSyncOperation(
        id: row.id,
        type: SyncOperationType.values.firstWhere(
          (e) => e.name == row.operationType,
        ),
        payload: Map<String, dynamic>.from(
          jsonDecode(row.payloadJson) as Map,
        ),
        createdAt: row.createdAt,
        attempts: row.attempts,
        lastError: row.lastError,
        nextAttemptAt: row.nextAttemptAt,
      );
    }).toList();
  }

  Future<List<PendingSyncOperation>> due() async {
    final now = DateTime.now();
    final all = await list();
    return all.where((op) => op.nextAttemptAt == null || !op.nextAttemptAt!.isAfter(now)).toList();
  }

  Future<PendingSyncOperation> enqueue(
    SyncOperationType type,
    Map<String, dynamic> payload,
  ) => enqueueWithId(_uuid.v4(), type, payload);

  Future<PendingSyncOperation> enqueueWithId(
    String operationId,
    SyncOperationType type,
    Map<String, dynamic> payload,
  ) async {
    final op = PendingSyncOperation(
      id: operationId,
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );

    await db.into(db.pendingOperations).insert(
          PendingOperationsCompanion.insert(
            id: op.id,
            operationType: type.name,
            payloadJson: jsonEncode(payload),
            createdAt: op.createdAt,
          ),
        );
    return op;
  }

  Future<void> remove(String operationId) {
    return (db.delete(db.pendingOperations)
          ..where((row) => row.id.equals(operationId)))
        .go();
  }

  Future<void> markFailure(String operationId, Object error) async {
    final row = await (db.select(db.pendingOperations)
          ..where((row) => row.id.equals(operationId)))
        .getSingleOrNull();
    if (row == null) return;

    final nextAttempts = row.attempts + 1;
    final minutes = switch (nextAttempts) {
      1 => 1,
      2 => 2,
      3 => 5,
      4 => 15,
      5 => 30,
      _ => 60,
    };

    await (db.update(db.pendingOperations)
          ..where((r) => r.id.equals(operationId)))
        .write(
      PendingOperationsCompanion(
        attempts: Value(nextAttempts),
        lastError: Value(error.toString()),
        nextAttemptAt: Value(DateTime.now().add(Duration(minutes: minutes))),
      ),
    );
  }

  Future<int> count() async {
    final countExp = db.pendingOperations.id.count();
    final query = db.selectOnly(db.pendingOperations)
      ..addColumns([countExp]);
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }
}
