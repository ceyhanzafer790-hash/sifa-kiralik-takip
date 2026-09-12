import 'api_client.dart';

class DocumentComplianceRepository {
  DocumentComplianceRepository({ApiClient? api})
      : api = api ?? ApiClient();

  final ApiClient api;

  Future<List<Map<String, dynamic>>> missing() async {
    final data = await api.getJson(
      '/documents/compliance?only_missing=true&limit=500',
    ) as List;

    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> createException({
    required String rentalId,
    String? movementId,
    required String documentType,
    required String reason,
  }) async {
    await api.postJson(
      '/documents/compliance/exceptions',
      {
        'rental_record_id': rentalId,
        'rental_movement_id': movementId,
        'document_type': documentType,
        'reason': reason,
      },
    );
  }

  Future<List<Map<String, dynamic>>> exceptions() async {
    final data = await api.getJson(
      '/documents/compliance/exceptions?active_only=true',
    ) as List;

    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> revokeException(String id) async {
    await api.postJson(
      '/documents/compliance/exceptions/$id/revoke',
      const {},
    );
  }
}
