import '../models/models.dart';

class RentalRateService {
  RentalItemRate? rateAt({
    required RentalTrackingRecord record,
    required String productId,
    required DateTime date,
  }) {
    final matches = record.itemRates
        .where((r) =>
            r.productId == productId &&
            !r.effectiveFrom.isAfter(date))
        .toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));

    return matches.isEmpty ? null : matches.first;
  }

  double? estimatedMonthlyAmount({
    required RentalTrackingRecord record,
    required RentalItemState item,
    required DateTime date,
  }) {
    final rate = rateAt(
      record: record,
      productId: item.product.id,
      date: date,
    );
    if (rate == null) return null;

    return switch (rate.rateType) {
      RentalRateType.perUnitMonthly =>
        rate.amount * item.remainingQuantity,
      RentalRateType.fixedMonthly => rate.amount,
    };
  }
}
