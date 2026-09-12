import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_config.dart';
import '../services/app_status_service.dart';
import '../services/app_version.dart';
import '../services/auto_sync_coordinator.dart';
import '../services/role_service.dart';
import 'admin_hub_screen.dart';
import 'conflict_resolution_screen.dart';
import 'customer_list_screen.dart';
import 'dashboard_screen.dart';
import 'global_search_screen.dart';
import 'materials_screen.dart';
import 'reminder_center_screen.dart';
import 'reports_screen.dart';
import 'shipment_screen.dart';
import 'stock_count_screen.dart';
import 'stock_maintenance_screen.dart';
import 'stock_source_screen.dart';

class AppShell extends StatefulWidget {
  final Future<void> Function() onLogout;
  final Future<void> Function() onServerSettings;

  const AppShell({
    super.key,
    required this.onLogout,
    required this.onServerSettings,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  AutoSyncStatus syncStatus = const AutoSyncStatus.offline();

  final sync = AutoSyncCoordinator();
  final roles = RoleService();
  final appStatusService = AppStatusService();

  StreamSubscription<AutoSyncStatus>? syncSub;
  Timer? runtimeTimer;

  AppRole? role;
  AppRuntimeStatus? runtime;
  bool loadingAccess = true;

  @override
  void initState() {
    super.initState();

    syncSub = sync.statusStream.listen((status) {
      if (mounted) setState(() => syncStatus = status);
    });

    _bootstrap();

    runtimeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshRuntime(),
    );
  }

  Future<void> _bootstrap() async {
    final currentRole = await roles.currentRole();

    AppRuntimeStatus currentRuntime;
    try {
      currentRuntime = await appStatusService.fetch();
    } catch (_) {
      currentRuntime = await appStatusService.cached();
    }

    if (!mounted) return;

    setState(() {
      role = currentRole;
      runtime = currentRuntime;
      loadingAccess = false;
      index = 0;
    });

    if (!currentRuntime.updateRequired) {
      await sync.start();
    }
  }

  Future<void> _refreshRuntime() async {
    try {
      final status = await appStatusService.fetch();

      if (status.updateRequired) {
        await sync.stop();
      } else {
        await sync.start();
      }

      if (!mounted) return;
      setState(() {
        runtime = status;
        final max = _navItems().length - 1;
        if (index > max) index = 0;
      });
    } catch (_) {
      // Sunucu yoksa son bilinen runtime ayarı korunur.
    }
  }

  @override
  void dispose() {
    runtimeTimer?.cancel();
    syncSub?.cancel();
    sync.dispose();
    super.dispose();
  }

  List<_NavItem> _navItems() {
    final currentRole = role ?? AppRole.viewer;
    final status = runtime;

    final forcedReadOnly = status?.updateRequired == true;
    final staffMaintenance =
        currentRole == AppRole.staff &&
        status?.maintenanceMode == true;
    final readOnly = forcedReadOnly || staffMaintenance;

    final basic = <_NavItem>[
      const _NavItem(
        page: DashboardScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Genel',
        ),
      ),
      const _NavItem(
        page: CustomerListScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Müşteriler',
        ),
      ),
      const _NavItem(
        page: MaterialsScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: 'Malzeme',
        ),
      ),
    ];

    if (currentRole == AppRole.viewer || readOnly) {
      return basic;
    }

    final operational = <_NavItem>[
      ...basic,
      const _NavItem(
        page: ShipmentScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.local_shipping_outlined),
          selectedIcon: Icon(Icons.local_shipping),
          label: 'Sevkiyat',
        ),
      ),
      const _NavItem(
        page: StockCountScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Sayım',
        ),
      ),
      const _NavItem(
        page: StockMaintenanceScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.warehouse_outlined),
          selectedIcon: Icon(Icons.warehouse),
          label: 'Stok',
        ),
      ),
      const _NavItem(
        page: StockSourceScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.add_box_outlined),
          selectedIcon: Icon(Icons.add_box),
          label: 'Giriş',
        ),
      ),
    ];

    if (currentRole == AppRole.admin) {
      operational.add(
        const _NavItem(
          page: AdminHubScreen(),
          destination: NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: 'Yönetim',
          ),
        ),
      );
    }

    return operational;
  }

  @override
  Widget build(BuildContext context) {
    if (loadingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final items = _navItems();
    final safeIndex = index < items.length ? index : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ŞİFA İNŞAAT • KİRALIK TAKİP',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Hatırlatmalar',
            onPressed: () => _push(
              const ReminderCenterScreen(),
            ),
            icon: Badge(
              isLabelVisible: syncStatus.reminders > 0,
              label: Text('${syncStatus.reminders}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          if (syncStatus.conflicts > 0)
            IconButton(
              tooltip: 'Senkron çakışmaları',
              onPressed: () => _push(
                const ConflictResolutionScreen(),
              ),
              icon: Badge(
                label: Text('${syncStatus.conflicts}'),
                child: const Icon(Icons.sync_problem_outlined),
              ),
            ),
          if (role != AppRole.viewer &&
              runtime?.updateRequired != true)
            IconButton(
              tooltip: 'Raporlar',
              onPressed: () => _push(
                const ReportsScreen(),
              ),
              icon: const Icon(Icons.assessment_outlined),
            ),
          IconButton(
            tooltip: 'Genel arama',
            onPressed: () => _push(
              const GlobalSearchScreen(),
            ),
            icon: const Icon(Icons.search),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              avatar: Icon(_syncIcon(), size: 18),
              label: Text(_syncLabel()),
              onPressed:
                  syncStatus.online &&
                          runtime?.updateRequired != true
                      ? sync.syncNow
                      : null,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'runtime') {
                await _refreshRuntime();
              }
              if (value == 'server') {
                await ApiConfig.clear();
                await widget.onServerSettings();
              }
              if (value == 'logout') {
                await widget.onLogout();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  '${_roleLabel(role)} • v${AppVersion.current}',
                ),
              ),
              const PopupMenuItem(
                value: 'runtime',
                child: Text('Sunucu Durumunu Yenile'),
              ),
              const PopupMenuItem(
                value: 'server',
                child: Text('Sunucu Adresini Değiştir'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Çıkış Yap'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_banner() != null) _banner()!,
            Expanded(child: items[safeIndex].page),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) {
          setState(() => index = value);
        },
        destinations:
            items.map((e) => e.destination).toList(),
      ),
    );
  }

  Widget? _banner() {
    final status = runtime;
    if (status == null) return null;

    if (status.updateRequired) {
      return MaterialBanner(
        content: Text(
          'GÜNCELLEME GEREKLİ • Bu sürüm ${AppVersion.current}. '
          'Minimum desteklenen sürüm ${status.minClientVersion}. '
          'Sunucu işlemleri güvenlik için durduruldu.',
        ),
        leading: const Icon(Icons.system_update_alt),
        actions: [
          TextButton(
            onPressed: _refreshRuntime,
            child: const Text('Kontrol Et'),
          ),
        ],
      );
    }

    if (status.maintenanceMode) {
      return MaterialBanner(
        content: Text(
          status.maintenanceMessage?.trim().isNotEmpty == true
              ? status.maintenanceMessage!
              : 'Sistem bakım modunda.',
        ),
        leading: const Icon(Icons.build_circle_outlined),
        actions: [
          TextButton(
            onPressed: _refreshRuntime,
            child: const Text('Yenile'),
          ),
        ],
      );
    }

    if (status.updateAvailable) {
      return MaterialBanner(
        content: Text(
          'Yeni uygulama sürümü mevcut: '
          '${status.latestClientVersion}. '
          'Bu sürüm: ${AppVersion.current}.',
        ),
        leading: const Icon(Icons.new_releases_outlined),
        actions: [
          TextButton(
            onPressed: _refreshRuntime,
            child: const Text('Kontrol Et'),
          ),
        ],
      );
    }

    return null;
  }

  void _push(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  IconData _syncIcon() {
    if (runtime?.updateRequired == true) {
      return Icons.system_update_alt;
    }
    if (!syncStatus.online) return Icons.cloud_off_outlined;
    if (syncStatus.syncing) return Icons.sync;
    if (syncStatus.error != null) return Icons.cloud_off_outlined;
    if (syncStatus.pending > 0) return Icons.cloud_upload_outlined;
    return Icons.cloud_done_outlined;
  }

  String _syncLabel() {
    if (runtime?.updateRequired == true) {
      return 'Güncelleme gerekli';
    }
    if (!syncStatus.online) return 'Offline';
    if (syncStatus.syncing) return 'Senkronize ediliyor';
    if (syncStatus.error != null) return 'Senkron hatası';
    if (syncStatus.conflicts > 0) {
      return '${syncStatus.conflicts} çakışma';
    }
    if (syncStatus.pending > 0) {
      return '${syncStatus.pending} bekliyor';
    }
    return 'Güncel';
  }

  String _roleLabel(AppRole? value) => switch (value) {
        AppRole.admin => 'Admin',
        AppRole.staff => 'Personel',
        _ => 'Görüntüleyici',
      };
}

class _NavItem {
  final Widget page;
  final NavigationDestination destination;

  const _NavItem({
    required this.page,
    required this.destination,
  });
}
