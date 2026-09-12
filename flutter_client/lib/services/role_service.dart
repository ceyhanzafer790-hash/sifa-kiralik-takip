import 'app_status_service.dart';
import 'auth_service.dart';

enum AppRole {
  admin,
  staff,
  viewer,
}

class RoleService {
  RoleService({
    AuthService? auth,
    AppStatusService? appStatus,
  })  : auth = auth ?? AuthService(),
        appStatus = appStatus ?? AppStatusService();

  final AuthService auth;
  final AppStatusService appStatus;

  Future<AppRole> currentRole() async {
    final raw = await auth.getRole();
    return switch (raw) {
      'admin' => AppRole.admin,
      'staff' => AppRole.staff,
      _ => AppRole.viewer,
    };
  }

  Future<bool> canWrite() async {
    final role = await currentRole();

    if (role == AppRole.admin) return true;
    if (role != AppRole.staff) return false;

    final runtime = await appStatus.cached();
    return !runtime.maintenanceMode &&
        !runtime.updateRequired;
  }

  Future<bool> canSeeFinancials() async =>
      (await currentRole()) == AppRole.admin;

  Future<bool> isAdmin() async =>
      (await currentRole()) == AppRole.admin;
}
