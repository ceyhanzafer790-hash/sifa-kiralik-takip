import 'api_client.dart';

class StockApiRepository {
  StockApiRepository({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<List<Map<String, dynamic>>> allSummaries() async {
    final data = await api.getJson('/stock/summary') as List;
    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> productSummary(String productId) async {
    final data = await api.getJson('/stock/products/$productId/summary');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> repairComplete(
    Map<String, dynamic> payload,
  ) async {
    final data = await api.postJson('/stock/repair-complete', payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> writeOff(
    Map<String, dynamic> payload,
  ) async {
    final data = await api.postJson('/stock/write-off', payload);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createCount(
    Map<String, dynamic> payload,
  ) async {
    final data = await api.postJson('/stock/counts', payload);
    return Map<String, dynamic>.from(data as Map);
  }
}
