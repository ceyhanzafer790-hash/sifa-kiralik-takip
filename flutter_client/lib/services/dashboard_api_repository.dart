import 'api_client.dart';
import 'api_config.dart';
import 'local_dashboard_service.dart';

class DashboardApiRepository {
  DashboardApiRepository({
    ApiClient? api,
    LocalDashboardService? local,
  })  : api = api ?? ApiClient(),
        local = local ?? LocalDashboardService();

  final ApiClient api;
  final LocalDashboardService local;

  Future<Map<String, dynamic>> summary({
    required DateTime today,
    int days = 30,
  }) async {
    final localData = await local.summary(
      today: today,
      days: days,
    );

    if (!ApiConfig.configured) return localData;

    final date =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    try {
      final data = await api.getJson(
        '/dashboard/summary?today=$date&days=$days',
      );
      final cloud = Map<String, dynamic>.from(data as Map);
      cloud['source'] = 'server';
      return cloud;
    } catch (_) {
      return localData;
    }
  }
}
