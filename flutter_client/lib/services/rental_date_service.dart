String trDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

DateTime nextMonthlyRentalDate(DateTime originalOutboundDate, DateTime from) {
  final targetDay = originalOutboundDate.day;

  DateTime safeDate(int year, int month, int day) {
    final firstNextMonth =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  var candidate = safeDate(from.year, from.month, targetDay);
  final todayOnly = DateTime(from.year, from.month, from.day);
  if (candidate.isBefore(todayOnly)) {
    final nextMonth = from.month == 12 ? 1 : from.month + 1;
    final nextYear = from.month == 12 ? from.year + 1 : from.year;
    candidate = safeDate(nextYear, nextMonth, targetDay);
  }
  return candidate;
}
