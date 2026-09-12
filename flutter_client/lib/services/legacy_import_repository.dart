import 'api_client.dart';
class LegacyImportRepository {
  LegacyImportRepository({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;
  Future<List<Map<String, dynamic>>> pending() async {
    final data = await api.getJson('/legacy-import/items?status=pending_match') as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  Future<List<Map<String, dynamic>>> customers() async {
    final data = await api.getJson('/customers') as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  Future<List<Map<String, dynamic>>> rentals(String customerId) async {
    final data = await api.getJson('/customers/$customerId/rentals') as List;
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  Future<void> match({required String itemId, String? customerId, String? rentalId, required String status}) async {
    await api.patchJson('/legacy-import/items/$itemId/match', {
      'customer_id': customerId,
      'rental_record_id': rentalId,
      'import_status': status,
    });
  }
}
