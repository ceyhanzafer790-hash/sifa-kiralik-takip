import '../models/models.dart';
import 'rental_date_service.dart';

class RentalReminder {
  final RentalTrackingRecord record;
  final DateTime renewalDate;
  final bool invoiceRequired;
  final bool invoicePending;

  const RentalReminder({
    required this.record,
    required this.renewalDate,
    required this.invoiceRequired,
    required this.invoicePending,
  });

  bool get needsInvoiceReminder => invoiceRequired && invoicePending;
}

class RentalBillingService {
  DateTime renewalForMonth(
    RentalTrackingRecord record,
    DateTime monthReference,
  ) {
    final targetDay = record.originalOutboundDate.day;
    final year = monthReference.year;
    final month = monthReference.month;
    final firstNextMonth =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
    return DateTime(year, month, targetDay > lastDay ? lastDay : targetDay);
  }

  RentalBillingPeriod ensureBillingPeriod(
    RentalTrackingRecord record,
    DateTime renewalDate,
  ) {
    for (final period in record.billingPeriods) {
      if (_sameDay(period.renewalDate, renewalDate)) return period;
    }

    return RentalBillingPeriod(
      id: 'bill_${record.id}_${renewalDate.year}_${renewalDate.month}_${renewalDate.day}',
      rentalRecordId: record.id,
      renewalDate: renewalDate,
      invoicePreference: record.invoicePreference,
      invoiceStatus: record.invoicePreference == InvoicePreference.invoiceRequired
          ? InvoiceStatus.pending
          : InvoiceStatus.notRequired,
    );
  }

  List<RentalReminder> reminders({
    required Iterable<RentalTrackingRecord> records,
    required DateTime now,
    int lookAheadDays = 7,
  }) {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: lookAheadDays));

    final result = <RentalReminder>[];

    for (final record in records.where((r) => !r.isClosed)) {
      final renewal = nextMonthlyRentalDate(record.originalOutboundDate, now);
      if (renewal.isBefore(start) || renewal.isAfter(end)) continue;

      final period = ensureBillingPeriod(record, renewal);

      result.add(
        RentalReminder(
          record: record,
          renewalDate: renewal,
          invoiceRequired:
              record.invoicePreference == InvoicePreference.invoiceRequired,
          invoicePending: period.invoiceStatus == InvoiceStatus.pending,
        ),
      );
    }

    result.sort((a, b) => a.renewalDate.compareTo(b.renewalDate));
    return result;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
