import 'api_client.dart';

class AdminApiRepository {
  AdminApiRepository({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<List<Map<String, dynamic>>> users() async {
    final data = await api.getJson('/admin/users') as List;
    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final data = await api.postJson(
      '/admin/users',
      {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> setActive(String userId, bool active) async {
    await api.patchJson(
      '/admin/users/$userId/active',
      {'active': active},
    );
  }

  Future<void> setRole(String userId, String role) async {
    await api.patchJson(
      '/admin/users/$userId/role',
      {'role': role},
    );
  }

  Future<void> resetPassword(String userId, String password) async {
    await api.postJson(
      '/admin/users/$userId/reset-password',
      {'new_password': password},
    );
  }


Future<Map<String, dynamic>> productionReadiness() async {
  return Map<String, dynamic>.from(
    await api.getJson(
      '/admin/production-readiness',
    ) as Map,
  );
}

  Future<Map<String, dynamic>> systemHealth() async {
    final data = await api.getJson('/admin/system-health');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> migrationStatus() async {
    final data = await api.getJson('/admin/migration-status');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> backupStatus() async {
    final data = await api.getJson('/admin/backup-status');
    return Map<String, dynamic>.from(data as Map);
  }


Future<Map<String, dynamic>> audit({
  int limit = 100,
  int offset = 0,
  String? userId,
  String? entityType,
  String? action,
  String? query,
  DateTime? fromAt,
  DateTime? toAt,
}) async {
  final params = <String, String>{
    'limit': '$limit',
    'offset': '$offset',
    if (userId != null && userId.isNotEmpty)
      'user_id': userId,
    if (entityType != null && entityType.isNotEmpty)
      'entity_type': entityType,
    if (action != null && action.isNotEmpty)
      'action': action,
    if (query != null && query.trim().isNotEmpty)
      'q': query.trim(),
    if (fromAt != null)
      'from_at': fromAt.toIso8601String(),
    if (toAt != null)
      'to_at': toAt.toIso8601String(),
  };

  final qs = params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');

  return Map<String, dynamic>.from(
    await api.getJson('/audit?$qs') as Map,
  );
}


Future<Map<String, dynamic>> auditNavigation(
  String auditId,
) async {
  return Map<String, dynamic>.from(
    await api.getJson(
      '/audit/$auditId/navigation',
    ) as Map,
  );
}

Future<Map<String, dynamic>> auditFacets() async {
  return Map<String, dynamic>.from(
    await api.getJson('/audit/facets') as Map,
  );
}

Future<List<Map<String, dynamic>>> releases() async {
  final data = await api.getJson('/admin/releases') as List;
  return data
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

Future<void> deactivateRelease(String releaseId) async {
  await api.postJson(
    '/admin/releases/$releaseId/deactivate',
    const {},
  );
}
}
