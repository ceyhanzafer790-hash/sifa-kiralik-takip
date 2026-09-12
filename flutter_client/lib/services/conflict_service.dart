import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';
import 'api_client.dart';
import 'offline_sync_service.dart';
import 'rental_api_repository.dart';

class ConflictService {
  ConflictService({
    AppDatabase? db,
    OfflineSyncService? queue,
  })  : db = db ?? AppDatabase.instance,
        queue = queue ?? OfflineSyncService();

  final AppDatabase db;
  final OfflineSyncService queue;
  final _uuid = const Uuid();

  Future<void> record(
    PendingSyncOperation operation,
    ApiException error,
  ) async {
    final p = operation.payload;
    final rentalId = p['rental_record_id']?.toString();

    await db.into(db.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: _uuid.v4(),
            operationId: operation.id,
            operationType: operation.type.name,
            entityType: Value(_entityType(operation.type)),
            entityId: Value(
              p['period_id']?.toString() ??
                  p['rental_item_id']?.toString() ??
                  rentalId,
            ),
            rentalId: Value(rentalId),
            localPayloadJson: jsonEncode(p),
            serverPayloadJson: Value(
              error.data == null ? null : jsonEncode(error.data),
            ),
            message: error.message,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<List<SyncConflict>> openConflicts() {
    return (db.select(db.syncConflicts)
          ..where((r) => r.resolvedAt.isNull())
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .get();
  }

  Future<int> openCount() async {
    final exp = db.syncConflicts.id.count();
    final q = db.selectOnly(db.syncConflicts)
      ..addColumns([exp])
      ..where(db.syncConflicts.resolvedAt.isNull());
    final row = await q.getSingle();
    return row.read(exp) ?? 0;
  }

  Future<void> useServer(SyncConflict conflict) async {
    if (conflict.rentalId != null) {
      await RentalApiRepository().refreshRentalFromServer(
        conflict.rentalId!,
      );
    }
    await _resolve(conflict.id, 'server');
  }

  Future<void> retryMine(SyncConflict conflict) async {
    final payload = Map<String, dynamic>.from(
      jsonDecode(conflict.localPayloadJson) as Map,
    );

    final server = conflict.serverPayloadJson == null
        ? null
        : jsonDecode(conflict.serverPayloadJson!);

    final currentVersion = _currentVersion(server);
    if (currentVersion != null) {
      payload['expected_version'] = currentVersion;
    }

    final type = SyncOperationType.values.firstWhere(
      (e) => e.name == conflict.operationType,
    );

    await queue.enqueue(type, payload);
    await _resolve(conflict.id, 'retry_local');
  }

  Future<void> dismiss(SyncConflict conflict) =>
      _resolve(conflict.id, 'dismissed');

  Future<void> _resolve(String id, String resolution) async {
    await (db.update(db.syncConflicts)
          ..where((r) => r.id.equals(id)))
        .write(
      SyncConflictsCompanion(
        resolution: Value(resolution),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  int? _currentVersion(dynamic server) {
    if (server is Map) {
      final detail = server['detail'];
      if (detail is Map && detail['current_version'] is num) {
        return (detail['current_version'] as num).toInt();
      }
      if (server['current_version'] is num) {
        return (server['current_version'] as num).toInt();
      }
    }
    return null;
  }

  String _entityType(SyncOperationType type) => switch (type) {
        SyncOperationType.changeInvoicePreference => 'rental_record',
        SyncOperationType.updateBillingPeriod => 'rental_billing_period',
        _ => 'sync_operation',
      };
}
