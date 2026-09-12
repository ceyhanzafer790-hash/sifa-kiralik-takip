import 'api_client.dart';

class SalesApiRepository {
  SalesApiRepository({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<List<Map<String, dynamic>>> forCustomer(String customerId) async {
    final data = await api.getJson('/customers/$customerId/sales') as List;
    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> create(
    Map<String, dynamic> payload,
  ) async {
    final data = await api.postJson('/sales', payload);
    return Map<String, dynamic>.from(data as Map);
  }
}
