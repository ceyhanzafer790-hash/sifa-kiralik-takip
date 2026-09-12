import 'package:drift/drift.dart';

import '../database/local_database.dart';
import 'rental_date_service.dart';

class ReminderPlanner {
  ReminderPlanner({AppDatabase? db})
      : db = db ?? AppDatabase.instance;

  final AppDatabase db;

  Future<void> refresh({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    // Eski, onaylanmamış planı yeniden hesapla. Onaylanmış geçmiş tutulur.
    await (db.delete(db.localReminderEvents)
          ..where((r) => r.acknowledged.equals(false)))
        .go();

    final rentals = await (db.select(db.localRentals)
          ..where((r) => r.status.equals('active')))
        .get();

    final customers = {
      for (final c in await db.select(db.localCustomers).get()) c.id: c,
    };

    final billing = await db.select(db.localBillingPeriods).get();

    for (final rental in rentals) {
      final renewal = nextMonthlyRentalDate(
        rental.originalOutboundDate,
        today,
      );
      final renewalDay = DateTime(
        renewal.year,
        renewal.month,
        renewal.day,
        9,
      );

      final customerName =
          customers[rental.customerId]?.name ?? 'Müşteri';

      final soonAt = renewalDay.subtract(const Duration(days: 3));
      if (!soonAt.isBefore(today.subtract(const Duration(days: 1)))) {
        await _insert(
          id: '${rental.id}:${_date(renewal)}:rental_soon',
          rentalId: rental.id,
          reminderType: 'rental_soon',
          dueAt: soonAt,
          title: 'Kira yenilemesine 3 gün kaldı',
          body: '$customerName • ${_display(renewal)} kira yenilemesi',
          priority: 1,
        );
      }

      await _insert(
        id: '${rental.id}:${_date(renewal)}:rental_due',
        rentalId: rental.id,
        reminderType: 'rental_due',
        dueAt: renewalDay,
        title: 'Kira yenilemesi bugün',
        body: '$customerName • Kiralama Takibi yenileme günü',
        priority: 2,
      );

      if (rental.invoicePreference == 'invoice_required') {
        final period = billing.cast<LocalBillingPeriod?>().firstWhere(
              (b) =>
                  b != null &&
                  b.rentalId == rental.id &&
                  _sameDate(b.renewalDate, renewal),
              orElse: () => null,
            );

        final invoiceIssued = period?.invoiceStatus == 'issued';
        if (!invoiceIssued) {
          await _insert(
            id: '${rental.id}:${_date(renewal)}:invoice_due',
            rentalId: rental.id,
            reminderType: 'invoice_due',
            dueAt: renewalDay,
            title: 'FATURA KESİLECEK',
            body: '$customerName • ${_display(renewal)} kira dönemi',
            priority: 3,
          );
        }
      }
    }
  }

  Future<void> _insert({
    required String id,
    required String rentalId,
    required String reminderType,
    required DateTime dueAt,
    required String title,
    required String body,
    required int priority,
  }) async {
    final existing = await (db.select(db.localReminderEvents)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();

    if (existing?.acknowledged == true) return;

    await db.into(db.localReminderEvents).insertOnConflictUpdate(
          LocalReminderEventsCompanion.insert(
            id: id,
            rentalId: rentalId,
            reminderType: reminderType,
            dueAt: dueAt,
            title: title,
            body: body,
            priority: Value(priority),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<List<LocalReminderEvent>> active() {
    return (db.select(db.localReminderEvents)
          ..where((r) => r.acknowledged.equals(false))
          ..orderBy([
            (r) => OrderingTerm.desc(r.priority),
            (r) => OrderingTerm.asc(r.dueAt),
          ]))
        .get();
  }

  Future<int> pendingCount() async {
    final exp = db.localReminderEvents.id.count();
    final q = db.selectOnly(db.localReminderEvents)
      ..addColumns([exp])
      ..where(db.localReminderEvents.acknowledged.equals(false));
    final row = await q.getSingle();
    return row.read(exp) ?? 0;
  }

  Future<void> acknowledge(String id) {
    return (db.update(db.localReminderEvents)
          ..where((r) => r.id.equals(id)))
        .write(
      const LocalReminderEventsCompanion(
        acknowledged: Value(true),
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _display(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}
