import '../database/local_database.dart';
import 'rental_date_service.dart';

class LocalDashboardService {
  LocalDashboardService({AppDatabase? db})
      : db = db ?? AppDatabase.instance;

  final AppDatabase db;

  Future<Map<String, dynamic>> summary({
    required DateTime today,
    int days = 30,
  }) async {
    final rentals = await (db.select(db.localRentals)
          ..where((r) => r.status.equals('active')))
        .get();

    final customers = {
      for (final c in await db.select(db.localCustomers).get()) c.id: c,
    };
    final addresses = {
      for (final a in await db.select(db.localAddresses).get()) a.id: a,
    };

    final items = await db.select(db.localRentalItems).get();
    final movements = await db.select(db.localRentalMovements).get();
    final rates = await db.select(db.localRentalRates).get();
    final billing = await db.select(db.localBillingPeriods).get();
    final documents = await db.select(db.localRentalDocuments).get();
    final pendingDocs = await db.select(db.pendingFileUploads).get();
    final products = await db.select(db.localProducts).get();

    final end = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: days));

    final renewals = <Map<String, dynamic>>[];
    double estimatedRevenue = 0;
    var unpriced = 0;
    double receivable = 0;
    var receivableCount = 0;
    double overdueReceivable = 0;
    var overdueReceivableCount = 0;
    var missingDueDateCount = 0;
    var missingDocuments = 0;
    var missingRentalDocuments = 0;
    var activeRentalItemCount = 0;

    for (final rental in rentals) {
      final renewal = nextMonthlyRentalDate(
        rental.originalOutboundDate,
        today,
      );

      if (!renewal.isAfter(end)) {
        LocalBillingPeriod? period;
        for (final b in billing) {
          if (b.rentalId == rental.id &&
              _sameDay(b.renewalDate, renewal)) {
            period = b;
            break;
          }
        }

        renewals.add({
          'rental_record_id': rental.id,
          'customer_id': rental.customerId,
          'customer_name':
              customers[rental.customerId]?.name ?? 'Müşteri',
          'address_label': rental.addressId == null
              ? null
              : addresses[rental.addressId!]?.label,
          'renewal_date': renewal.toIso8601String(),
          'invoice_preference': rental.invoicePreference,
          'invoice_status': period?.invoiceStatus,
          'payment_status': period?.paymentStatus,
          'billed_amount': period?.billedAmount,
          'paid_amount': period?.paidAmount,
          'days_until': DateTime(
            renewal.year,
            renewal.month,
            renewal.day,
          ).difference(
            DateTime(today.year, today.month, today.day),
          ).inDays,
        });
      }

      final rentalItems =
          items.where((i) => i.rentalId == rental.id);

      for (final item in rentalItems) {
        final returned = movements
            .where(
              (m) =>
                  m.rentalItemId == item.id &&
                  m.movementType == 'inbound_return',
            )
            .fold<double>(0, (sum, m) => sum + m.quantity);

        final remaining = (item.initialQuantity - returned)
            .clamp(0.0, double.infinity)
            .toDouble();

        if (remaining <= 0) continue;
        activeRentalItemCount++;

        final itemRates = rates
            .where(
              (r) =>
                  r.rentalItemId == item.id &&
                  !r.effectiveFrom.isAfter(today),
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.effectiveFrom.compareTo(a.effectiveFrom);
            if (byDate != 0) return byDate;
            return b.updatedAt.compareTo(a.updatedAt);
          });

        if (itemRates.isEmpty) {
          unpriced++;
        } else {
          final rate = itemRates.first;
          estimatedRevenue += rate.rateType == 'fixed_monthly'
              ? rate.amount
              : rate.amount * remaining;
        }
      }

      final rentalDocs =
          documents.where((d) => d.rentalId == rental.id).toList();
      final rentalPendingDocs = pendingDocs
          .where((d) => d.rentalRecordId == rental.id)
          .toList();

      bool hasDocument(String type, {String? movementId}) {
        final synced = rentalDocs.any(
          (d) =>
              d.documentType == type &&
              (movementId == null || d.movementId == movementId),
        );
        final queued = rentalPendingDocs.any(
          (d) =>
              d.documentType == type &&
              (movementId == null ||
                  d.rentalMovementId == movementId),
        );
        return synced || queued;
      }

      var rentalMissing = 0;

      if (!hasDocument('contract')) {
        rentalMissing++;
      }

      final rentalMovements =
          movements.where((m) => m.rentalId == rental.id);

      for (final movement in rentalMovements) {
        final requiredType = movement.movementType == 'outbound'
            ? 'outbound_delivery'
            : movement.movementType == 'inbound_return'
                ? 'inbound_delivery'
                : null;

        if (requiredType == null) continue;

        if (!hasDocument(
          requiredType,
          movementId: movement.id,
        )) {
          rentalMissing++;
        }
      }

      if (rentalMissing > 0) {
        missingRentalDocuments++;
        missingDocuments += rentalMissing;
      }
    }

    for (final b in billing) {
      if (b.invoiceStatus != 'issued') continue;

      final balance =
          (b.billedAmount ?? 0) - (b.paidAmount ?? 0);

      if (balance > 0) {
        receivable += balance;
        receivableCount++;
      }
    }

    final invoiceDue = renewals.where(
      (r) =>
          r['invoice_preference'] == 'invoice_required' &&
          r['invoice_status'] != 'issued',
    );

    final unknownStock = products
        .where((p) => p.active && p.stockConfidence == 'unknown')
        .length;

    final todayMovementCount = movements
        .where((m) => _sameDay(m.movementDate, today))
        .length;

    return {
      'today': today.toIso8601String(),
      'window_days': days,
      'active_rental_count': rentals.length,
      'active_rental_item_count': activeRentalItemCount,
      'today_movement_count': todayMovementCount,
      'renewals': renewals,
      'renewal_due_today_count':
          renewals.where((r) => r['days_until'] == 0).length,
      'renewal_next_3_days_count': renewals
          .where(
            (r) =>
                (r['days_until'] as int) >= 0 &&
                (r['days_until'] as int) <= 3,
          )
          .length,
      'invoice_reminder_count': invoiceDue.length,
      'invoice_due_today_count':
          invoiceDue.where((r) => r['days_until'] == 0).length,
      'estimated_monthly_rental_revenue': estimatedRevenue,
      'estimated_revenue_unpriced_item_count': unpriced,
      'estimated_revenue_is_invoice': false,
      'issued_receivable_balance': receivable,
      'issued_receivable_count': receivableCount,
      'overdue_receivable_balance': overdueReceivable,
      'overdue_receivable_count': overdueReceivableCount,
      'open_invoice_missing_due_date_count': missingDueDateCount,
      'missing_document_rental_count': missingRentalDocuments,
      'missing_document_count': missingDocuments,
      'legacy_import_pending': null,
      'unknown_stock_product_count': unknownStock,
      'customer_count': customers.length,
      'source': 'local',
    };
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}
