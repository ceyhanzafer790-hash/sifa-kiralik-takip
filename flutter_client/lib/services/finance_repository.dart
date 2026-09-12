import 'api_client.dart';

class FinanceRepository {
  FinanceRepository({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<Map<String, dynamic>> receivables({
    String? customerId,
    String? query,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final params = <String, String>{
      if (customerId != null && customerId.isNotEmpty)
        'customer_id': customerId,
      if (query != null && query.trim().isNotEmpty)
        'q': query.trim(),
      if (fromDate != null)
        'from_date': _date(fromDate),
      if (toDate != null)
        'to_date': _date(toDate),
    };

    final suffix = _query(params);

    return Map<String, dynamic>.from(
      await api.getJson('/finance/receivables$suffix') as Map,
    );
  }

  Future<Map<String, dynamic>> receivableAging({
    required DateTime asOf,
    String? customerId,
    String? query,
  }) async {
    final params = <String, String>{
      'as_of': _date(asOf),
      if (customerId != null && customerId.isNotEmpty)
        'customer_id': customerId,
      if (query != null && query.trim().isNotEmpty)
        'q': query.trim(),
    };

    final suffix = _query(params);

    return Map<String, dynamic>.from(
      await api.getJson(
        '/finance/receivables/aging$suffix',
      ) as Map,
    );
  }


Future<Map<String, dynamic>> overdueReceivables({
  required DateTime asOf,
  String? customerId,
  String? query,
}) async {
  final params = <String, String>{
    'as_of': _date(asOf),
    if (customerId != null && customerId.isNotEmpty)
      'customer_id': customerId,
    if (query != null && query.trim().isNotEmpty)
      'q': query.trim(),
  };

  final suffix = _query(params);

  return Map<String, dynamic>.from(
    await api.getJson(
      '/finance/receivables/overdue$suffix',
    ) as Map,
  );
}

  Future<Map<String, dynamic>> revenueEstimate({
    String? customerId,
    String? query,
  }) async {
    final params = <String, String>{
      if (customerId != null && customerId.isNotEmpty)
        'customer_id': customerId,
      if (query != null && query.trim().isNotEmpty)
        'q': query.trim(),
    };

    final suffix = _query(params);

    return Map<String, dynamic>.from(
      await api.getJson(
        '/finance/rental-revenue-estimate$suffix',
      ) as Map,
    );
  }

  String _query(Map<String, String> params) {
    if (params.isEmpty) return '';

    return '?${params.entries.map(
      (e) =>
          '${Uri.encodeQueryComponent(e.key)}='
          '${Uri.encodeQueryComponent(e.value)}',
    ).join('&')}';
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
