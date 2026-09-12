import 'api_client.dart';

class ReleaseRepository {
  ReleaseRepository({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<List<Map<String, dynamic>>> manifest({
    String? platform,
  }) async {
    final suffix = platform == null
        ? ''
        : '?platform=${Uri.encodeQueryComponent(platform)}';

    final data = Map<String, dynamic>.from(
      await api.getJson(
        '/app/release-manifest$suffix',
      ) as Map,
    );

    return ((data['artifacts'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
