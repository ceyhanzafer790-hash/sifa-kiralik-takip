import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_database.g.dart';


class LocalCustomers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get unit => text()();
  TextColumn get tradeMode => text()();
  TextColumn get stockConfidence => text().withDefault(const Constant('unknown'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalRentals extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get addressId => text().nullable()();
  DateTimeColumn get originalOutboundDate => dateTime()();
  TextColumn get invoicePreference => text()();
  TextColumn get status => text()();
  TextColumn get note => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}


class LocalAddresses extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get label => text()();
  TextColumn get fullAddress => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalRentalItems extends Table {
  TextColumn get id => text()();
  TextColumn get rentalId => text()();
  TextColumn get productId => text()();
  RealColumn get initialQuantity => real()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalRentalMovements extends Table {
  TextColumn get id => text()();
  TextColumn get rentalId => text()();
  TextColumn get rentalItemId => text()();
  TextColumn get productId => text()();
  TextColumn get movementType => text()();
  RealColumn get quantity => real()();
  DateTimeColumn get movementDate => dateTime()();
  TextColumn get returnCondition => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalRentalRates extends Table {
  TextColumn get id => text()();
  TextColumn get rentalId => text()();
  TextColumn get rentalItemId => text()();
  TextColumn get productId => text()();
  DateTimeColumn get effectiveFrom => dateTime()();
  RealColumn get amount => real()();
  TextColumn get rateType => text()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalRentalDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get rentalId => text()();
  TextColumn get movementId => text().nullable()();
  TextColumn get documentType => text()();
  TextColumn get originalFileName => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalBillingPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get rentalId => text()();
  DateTimeColumn get renewalDate => dateTime()();
  TextColumn get invoiceStatus => text()();
  TextColumn get paymentStatus => text()();
  RealColumn get billedAmount => real().nullable()();
  RealColumn get paidAmount => real().nullable()();
  TextColumn get invoiceNo => text().nullable()();
  DateTimeColumn get invoiceDate => dateTime().nullable()();
  DateTimeColumn get paymentDueDate => dateTime().nullable()();
  TextColumn get snapshotJson => text().nullable()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();
  IntColumn get rowVersion => integer().withDefault(const Constant(1))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CachedEntities extends Table {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get jsonData => text()();
  IntColumn get serverSeq => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {entityType, entityId};
}

class PendingOperations extends Table {
  TextColumn get id => text()();
  TextColumn get operationType => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class PendingFileUploads extends Table {
  TextColumn get id => text()();
  TextColumn get rentalRecordId => text()();
  TextColumn get rentalMovementId => text().nullable()();
  TextColumn get documentType => text()();
  TextColumn get localPath => text()();
  TextColumn get originalFileName => text()();
  TextColumn get mimeType => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}


class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get operationId => text()();
  TextColumn get operationType => text()();
  TextColumn get entityType => text().nullable()();
  TextColumn get entityId => text().nullable()();
  TextColumn get rentalId => text().nullable()();
  TextColumn get localPayloadJson => text()();
  TextColumn get serverPayloadJson => text().nullable()();
  TextColumn get message => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get resolution => text().nullable()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class LocalReminderEvents extends Table {
  TextColumn get id => text()();
  TextColumn get rentalId => text()();
  TextColumn get reminderType => text()();
  DateTimeColumn get dueAt => dateTime()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  BoolColumn get acknowledged => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncStateRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    LocalCustomers,
    LocalProducts,
    LocalRentals,
    LocalAddresses,
    LocalRentalItems,
    LocalRentalMovements,
    LocalRentalRates,
    LocalRentalDocuments,
    LocalBillingPeriods,
    CachedEntities,
    PendingOperations,
    PendingFileUploads,
    SyncConflicts,
    LocalReminderEvents,
    SyncStateRows,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(localAddresses);
            await m.createTable(localRentalItems);
            await m.createTable(localRentalMovements);
            await m.createTable(localRentalRates);
            await m.createTable(localRentalDocuments);
            await m.createTable(localBillingPeriods);
          }
          if (from < 3) {
            await m.addColumn(localRentals, localRentals.rowVersion);
            await m.addColumn(localBillingPeriods, localBillingPeriods.snapshotJson);
            await m.addColumn(localBillingPeriods, localBillingPeriods.pendingSync);
            await m.addColumn(localBillingPeriods, localBillingPeriods.rowVersion);
            await m.addColumn(pendingOperations, pendingOperations.nextAttemptAt);
            await m.addColumn(pendingFileUploads, pendingFileUploads.nextAttemptAt);
          }
          if (from < 4) {
            await m.createTable(syncConflicts);
            await m.createTable(localReminderEvents);
          }
          if (from < 5) {
            await m.addColumn(localProducts, localProducts.stockConfidence);
          }
          if (from < 6) {
            await m.addColumn(
              localBillingPeriods,
              localBillingPeriods.paymentDueDate,
            );
          }
        },
      );

  Future<void> cacheEntity({
    required String entityType,
    required String entityId,
    required String jsonData,
    required int serverSeq,
  }) {
    return into(cachedEntities).insertOnConflictUpdate(
      CachedEntitiesCompanion.insert(
        entityType: entityType,
        entityId: entityId,
        jsonData: jsonData,
        serverSeq: Value(serverSeq),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<List<CachedEntity>> cachedByType(String type) {
    return (select(cachedEntities)
          ..where((row) => row.entityType.equals(type))
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
        .get();
  }

  Future<CachedEntity?> cachedOne(String type, String id) {
    return (select(cachedEntities)
          ..where(
            (row) =>
                row.entityType.equals(type) &
                row.entityId.equals(id),
          ))
        .getSingleOrNull();
  }

  Future<void> removeCached(String type, String id) {
    return (delete(cachedEntities)
          ..where(
            (row) =>
                row.entityType.equals(type) &
                row.entityId.equals(id),
          ))
        .go();
  }

  Future<void> setSyncState(String key, String value) {
    return into(syncStateRows).insertOnConflictUpdate(
      SyncStateRowsCompanion.insert(
        key: key,
        value: value,
      ),
    );
  }

  Future<String?> getSyncState(String key) async {
    final row = await (select(syncStateRows)
          ..where((row) => row.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'sifa_kiralik.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
