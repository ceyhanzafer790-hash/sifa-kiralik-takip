import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/local_database.dart';

class LocalDomainCache {
  LocalDomainCache({AppDatabase? db})
      : db = db ?? AppDatabase.instance;

  final AppDatabase db;

  Future<void> upsertCustomer({
    required String id,
    required String name,
    String? phone,
    String? notes,
    required bool pendingSync,
  }) async {
    await db.into(db.localCustomers).insertOnConflictUpdate(
          LocalCustomersCompanion.insert(
            id: id,
            name: name,
            phone: Value(phone),
            notes: Value(notes),
            pendingSync: Value(pendingSync),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalCustomer>> customers() {
    return (db.select(db.localCustomers)
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .get();
  }

  Future<LocalCustomer?> customer(String id) {
    return (db.select(db.localCustomers)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertAddress({
    required String id,
    required String customerId,
    required String label,
    String? fullAddress,
    required bool pendingSync,
  }) async {
    await db.into(db.localAddresses).insertOnConflictUpdate(
          LocalAddressesCompanion.insert(
            id: id,
            customerId: customerId,
            label: label,
            fullAddress: Value(fullAddress),
            pendingSync: Value(pendingSync),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalAddress>> addresses(String customerId) {
    return (db.select(db.localAddresses)
          ..where((r) => r.customerId.equals(customerId))
          ..orderBy([(r) => OrderingTerm.asc(r.label)]))
        .get();
  }

  Future<LocalAddress?> address(String id) {
    return (db.select(db.localAddresses)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertProduct({
    required String id,
    required String name,
    required String category,
    required String unit,
    required String tradeMode,
    String stockConfidence = 'unknown',
    bool active = true,
  }) async {
    await db.into(db.localProducts).insertOnConflictUpdate(
          LocalProductsCompanion.insert(
            id: id,
            name: name,
            category: category,
            unit: unit,
            tradeMode: tradeMode,
            stockConfidence: Value(stockConfidence),
            active: Value(active),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalProduct>> products() {
    return (db.select(db.localProducts)
          ..where((r) => r.active.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .get();
  }

  Future<void> upsertRental({
    required String id,
    required String customerId,
    String? addressId,
    required DateTime originalOutboundDate,
    required String invoicePreference,
    required String status,
    String? note,
    required bool pendingSync,
    int rowVersion = 1,
  }) async {
    await db.into(db.localRentals).insertOnConflictUpdate(
          LocalRentalsCompanion.insert(
            id: id,
            customerId: customerId,
            addressId: Value(addressId),
            originalOutboundDate: originalOutboundDate,
            invoicePreference: invoicePreference,
            status: status,
            note: Value(note),
            pendingSync: Value(pendingSync),
            rowVersion: Value(rowVersion),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalRental>> rentalsForCustomer(String customerId) {
    return (db.select(db.localRentals)
          ..where((r) => r.customerId.equals(customerId))
          ..orderBy([
            (r) => OrderingTerm.desc(r.originalOutboundDate),
          ]))
        .get();
  }

  Future<LocalRental?> rental(String id) {
    return (db.select(db.localRentals)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertRentalItem({
    required String id,
    required String rentalId,
    required String productId,
    required double initialQuantity,
    required bool pendingSync,
  }) async {
    await db.into(db.localRentalItems).insertOnConflictUpdate(
          LocalRentalItemsCompanion.insert(
            id: id,
            rentalId: rentalId,
            productId: productId,
            initialQuantity: initialQuantity,
            pendingSync: Value(pendingSync),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalRentalItem>> rentalItems(String rentalId) {
    return (db.select(db.localRentalItems)
          ..where((r) => r.rentalId.equals(rentalId)))
        .get();
  }

  Future<LocalRentalItem?> rentalItem(String id) {
    return (db.select(db.localRentalItems)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertMovement({
    required String id,
    required String rentalId,
    required String rentalItemId,
    required String productId,
    required String movementType,
    required double quantity,
    required DateTime movementDate,
    String? returnCondition,
    String? note,
    required bool pendingSync,
  }) async {
    await db.into(db.localRentalMovements).insertOnConflictUpdate(
          LocalRentalMovementsCompanion.insert(
            id: id,
            rentalId: rentalId,
            rentalItemId: rentalItemId,
            productId: productId,
            movementType: movementType,
            quantity: quantity,
            movementDate: movementDate,
            returnCondition: Value(returnCondition),
            note: Value(note),
            pendingSync: Value(pendingSync),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalRentalMovement>> movements(String rentalId) {
    return (db.select(db.localRentalMovements)
          ..where((r) => r.rentalId.equals(rentalId))
          ..orderBy([
            (r) => OrderingTerm.desc(r.movementDate),
          ]))
        .get();
  }

  Future<void> upsertRate({
    required String id,
    required String rentalId,
    required String rentalItemId,
    required String productId,
    required DateTime effectiveFrom,
    required double amount,
    required String rateType,
    required bool pendingSync,
  }) async {
    await db.into(db.localRentalRates).insertOnConflictUpdate(
          LocalRentalRatesCompanion.insert(
            id: id,
            rentalId: rentalId,
            rentalItemId: rentalItemId,
            productId: productId,
            effectiveFrom: effectiveFrom,
            amount: amount,
            rateType: rateType,
            pendingSync: Value(pendingSync),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalRentalRate>> rates(String rentalId) {
    return (db.select(db.localRentalRates)
          ..where((r) => r.rentalId.equals(rentalId))
          ..orderBy([
            (r) => OrderingTerm.desc(r.effectiveFrom),
          ]))
        .get();
  }

  Future<void> replaceDocuments(
    String rentalId,
    List<Map<String, dynamic>> documents,
  ) async {
    await db.transaction(() async {
      await (db.delete(db.localRentalDocuments)
            ..where((r) => r.rentalId.equals(rentalId)))
          .go();

      for (final doc in documents) {
        await db.into(db.localRentalDocuments).insert(
              LocalRentalDocumentsCompanion.insert(
                id: doc['id'].toString(),
                rentalId: rentalId,
                movementId: Value(doc['rental_movement_id']?.toString()),
                documentType: doc['document_type'].toString(),
                originalFileName: doc['original_file_name'].toString(),
                createdAt: DateTime.parse(doc['created_at'].toString()),
              ),
            );
      }
    });
  }

  Future<List<LocalRentalDocument>> documents(String rentalId) {
    return (db.select(db.localRentalDocuments)
          ..where((r) => r.rentalId.equals(rentalId))
          ..orderBy([
            (r) => OrderingTerm.desc(r.createdAt),
          ]))
        .get();
  }

  Future<List<Map<String, dynamic>>> pendingDocuments(String rentalId) async {
    final rows = await (db.select(db.pendingFileUploads)
          ..where((r) => r.rentalRecordId.equals(rentalId))
          ..orderBy([
            (r) => OrderingTerm.desc(r.createdAt),
          ]))
        .get();

    return rows
        .map(
          (r) => {
            'id': r.id,
            'rental_record_id': r.rentalRecordId,
            'rental_movement_id': r.rentalMovementId,
            'document_type': r.documentType,
            'original_file_name': r.originalFileName,
            'created_at': r.createdAt.toIso8601String(),
          },
        )
        .toList();
  }

  Future<void> replaceBillingPeriods(
    String rentalId,
    List<Map<String, dynamic>> periods,
  ) async {
    await db.transaction(() async {
      await (db.delete(db.localBillingPeriods)
            ..where((r) => r.rentalId.equals(rentalId)))
          .go();

      for (final p in periods) {
        await db.into(db.localBillingPeriods).insert(
              LocalBillingPeriodsCompanion.insert(
                id: p['id'].toString(),
                rentalId: rentalId,
                renewalDate: DateTime.parse(p['renewal_date'].toString()),
                invoiceStatus:
                    p['invoice_status']?.toString() ?? 'not_required',
                paymentStatus:
                    p['payment_status']?.toString() ?? 'pending',
                billedAmount: Value(
                  (p['billed_amount'] as num?)?.toDouble(),
                ),
                paidAmount: Value(
                  (p['paid_amount'] as num?)?.toDouble(),
                ),
                invoiceNo: Value(p['invoice_no']?.toString()),
                invoiceDate: Value(
                  p['invoice_date'] == null
                      ? null
                      : DateTime.parse(p['invoice_date'].toString()),
                ),
                paymentDueDate: Value(
                  p['payment_due_date'] == null
                      ? null
                      : DateTime.parse(p['payment_due_date'].toString()),
                ),
                snapshotJson: Value(
                  p['quantity_rate_snapshot'] == null
                      ? null
                      : jsonEncode(p['quantity_rate_snapshot']),
                ),
                pendingSync: const Value(false),
                rowVersion: Value((p['row_version'] as num?)?.toInt() ?? 1),
                updatedAt: DateTime.now(),
              ),
            );
      }
    });
  }

  Future<List<LocalBillingPeriod>> billingPeriods(String rentalId) {
    return (db.select(db.localBillingPeriods)
          ..where((r) => r.rentalId.equals(rentalId))
          ..orderBy([
            (r) => OrderingTerm.desc(r.renewalDate),
          ]))
        .get();
  }

  Future<void> markCustomerSynced(String id) async {
    await (db.update(db.localCustomers)..where((r) => r.id.equals(id))).write(
      LocalCustomersCompanion(
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markAddressSynced(String id) async {
    await (db.update(db.localAddresses)..where((r) => r.id.equals(id))).write(
      LocalAddressesCompanion(
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markRentalSynced(String id) async {
    await (db.update(db.localRentals)..where((r) => r.id.equals(id))).write(
      LocalRentalsCompanion(
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markRentalItemSynced(String id) async {
    await (db.update(db.localRentalItems)..where((r) => r.id.equals(id))).write(
      LocalRentalItemsCompanion(
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markMovementSynced(String id) async {
    await (db.update(db.localRentalMovements)..where((r) => r.id.equals(id))).write(
      LocalRentalMovementsCompanion(
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markRateSynced(String id) async {
    await (db.update(db.localRentalRates)..where((r) => r.id.equals(id))).write(
      LocalRentalRatesCompanion(
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }


  Future<void> upsertBillingPeriod({
    required String id,
    required String rentalId,
    required DateTime renewalDate,
    required String invoiceStatus,
    required String paymentStatus,
    double? billedAmount,
    double? paidAmount,
    String? invoiceNo,
    DateTime? invoiceDate,
    DateTime? paymentDueDate,
    String? snapshotJson,
    required bool pendingSync,
    int rowVersion = 1,
  }) async {
    await db.into(db.localBillingPeriods).insertOnConflictUpdate(
      LocalBillingPeriodsCompanion.insert(
        id: id,
        rentalId: rentalId,
        renewalDate: renewalDate,
        invoiceStatus: invoiceStatus,
        paymentStatus: paymentStatus,
        billedAmount: Value(billedAmount),
        paidAmount: Value(paidAmount),
        invoiceNo: Value(invoiceNo),
        invoiceDate: Value(invoiceDate),
        paymentDueDate: Value(paymentDueDate),
        snapshotJson: Value(snapshotJson),
        pendingSync: Value(pendingSync),
        rowVersion: Value(rowVersion),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<LocalBillingPeriod?> billingPeriodByDate(String rentalId, DateTime renewalDate) {
    final start = DateTime(renewalDate.year, renewalDate.month, renewalDate.day);
    return (db.select(db.localBillingPeriods)
      ..where((r) => r.rentalId.equals(rentalId) & r.renewalDate.equals(start)))
      .getSingleOrNull();
  }

  Future<void> markBillingPeriodSynced(String id) async {
    await (db.update(db.localBillingPeriods)..where((r) => r.id.equals(id))).write(
      LocalBillingPeriodsCompanion(
        pendingSync: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

}
