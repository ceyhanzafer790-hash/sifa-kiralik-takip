import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'app_version.dart';

class AppRuntimeStatus {
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String minClientVersion;
  final String latestClientVersion;
  final bool enforceMinClientVersion;

  const AppRuntimeStatus({
    required this.maintenanceMode,
    required this.maintenanceMessage,
    required this.minClientVersion,
    required this.latestClientVersion,
    required this.enforceMinClientVersion,
  });

  bool get updateRequired =>
      enforceMinClientVersion &&
      _compareVersions(
            AppVersion.current,
            minClientVersion,
          ) <
          0;

  bool get updateAvailable =>
      _compareVersions(
        AppVersion.current,
        latestClientVersion,
      ) <
      0;

  static int _compareVersions(String a, String b) {
    final av = _parts(a);
    final bv = _parts(b);

    for (var i = 0; i < 3; i++) {
      if (av[i] != bv[i]) return av[i].compareTo(bv[i]);
    }
    return 0;
  }

  static List<int> _parts(String value) {
    final core = value
        .split('+')
        .first
        .split('-')
        .first;
    final raw = core.split('.');

    return List<int>.generate(
      3,
      (i) => i < raw.length
          ? int.tryParse(raw[i]) ?? 0
          : 0,
    );
  }
}

class AppStatusService {
  AppStatusService({ApiClient? api}) : api = api ?? ApiClient();

  static const _maintenanceKey = 'sifa_runtime_maintenance';
  static const _maintenanceMessageKey =
      'sifa_runtime_maintenance_message';
  static const _minVersionKey = 'sifa_runtime_min_version';
  static const _latestVersionKey = 'sifa_runtime_latest_version';
  static const _enforceVersionKey = 'sifa_runtime_enforce_version';

  final ApiClient api;

  Future<AppRuntimeStatus> fetch() async {
    final data = Map<String, dynamic>.from(
      await api.getJson('/app/status') as Map,
    );

    final status = AppRuntimeStatus(
      maintenanceMode:
          data['maintenance_mode'] == true,
      maintenanceMessage:
          data['maintenance_message']?.toString(),
      minClientVersion:
          data['min_client_version']?.toString() ?? '0.0.0',
      latestClientVersion:
          data['latest_client_version']?.toString() ??
              AppVersion.current,
      enforceMinClientVersion:
          data['enforce_min_client_version'] == true,
    );

    await _save(status);
    return status;
  }

  Future<AppRuntimeStatus> cached() async {
    final prefs = await SharedPreferences.getInstance();

    return AppRuntimeStatus(
      maintenanceMode:
          prefs.getBool(_maintenanceKey) ?? false,
      maintenanceMessage:
          prefs.getString(_maintenanceMessageKey),
      minClientVersion:
          prefs.getString(_minVersionKey) ?? '0.0.0',
      latestClientVersion:
          prefs.getString(_latestVersionKey) ??
              AppVersion.current,
      enforceMinClientVersion:
          prefs.getBool(_enforceVersionKey) ?? false,
    );
  }

  Future<bool> cachedMaintenanceMode() async =>
      (await cached()).maintenanceMode;

  Future<bool> cachedUpdateRequired() async =>
      (await cached()).updateRequired;

  Future<AppRuntimeStatus> updateAdmin({
    required bool maintenanceMode,
    String? maintenanceMessage,
    required String minClientVersion,
    required String latestClientVersion,
    required bool enforceMinClientVersion,
  }) async {
    final data = Map<String, dynamic>.from(
      await api.patchJson(
        '/admin/app-status',
        {
          'maintenance_mode': maintenanceMode,
          'maintenance_message':
              maintenanceMessage?.trim().isEmpty == true
                  ? null
                  : maintenanceMessage?.trim(),
          'min_client_version': minClientVersion.trim(),
          'latest_client_version': latestClientVersion.trim(),
          'enforce_min_client_version':
              enforceMinClientVersion,
        },
      ) as Map,
    );

    final status = AppRuntimeStatus(
      maintenanceMode:
          data['maintenance_mode'] == true,
      maintenanceMessage:
          data['maintenance_message']?.toString(),
      minClientVersion:
          data['min_client_version'].toString(),
      latestClientVersion:
          data['latest_client_version'].toString(),
      enforceMinClientVersion:
          data['enforce_min_client_version'] == true,
    );

    await _save(status);
    return status;
  }

  Future<void> _save(AppRuntimeStatus status) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(
      _maintenanceKey,
      status.maintenanceMode,
    );

    if (status.maintenanceMessage == null) {
      await prefs.remove(_maintenanceMessageKey);
    } else {
      await prefs.setString(
        _maintenanceMessageKey,
        status.maintenanceMessage!,
      );
    }

    await prefs.setString(
      _minVersionKey,
      status.minClientVersion,
    );
    await prefs.setString(
      _latestVersionKey,
      status.latestClientVersion,
    );
    await prefs.setBool(
      _enforceVersionKey,
      status.enforceMinClientVersion,
    );
  }
}
