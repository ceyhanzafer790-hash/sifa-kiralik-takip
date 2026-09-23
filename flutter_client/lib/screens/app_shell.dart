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
import 'receivables_screen.dart';
import 'reminder_center_screen.dart';
import 'rentals_overview_screen.dart';
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
      setState(() => runtime = status);
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

  bool get _readOnly {
    final currentRole = role ?? AppRole.viewer;
    final status = runtime;

    return status?.updateRequired == true ||
        (currentRole == AppRole.staff && status?.maintenanceMode == true);
  }

  bool get _canWrite => role != AppRole.viewer && !_readOnly;

  List<_NavItem> _navItems() {
    return [
      const _NavItem(
        page: DashboardScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Ana Sayfa',
        ),
      ),
      const _NavItem(
        page: RentalsOverviewScreen(),
        destination: NavigationDestination(
          icon: Icon(Icons.event_repeat_outlined),
          selectedIcon: Icon(Icons.event_repeat),
          label: 'Kiralamalar',
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
      _NavItem(
        page: _MorePage(
          role: role ?? AppRole.viewer,
          readOnly: _readOnly,
          syncStatus: syncStatus,
          onOpen: _push,
          onRefreshRuntime: _refreshRuntime,
          onServerSettings: () async {
            await ApiConfig.clear();
            await widget.onServerSettings();
          },
          onLogout: widget.onLogout,
        ),
        destination: const NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Daha Fazla',
        ),
      ),
    ];
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
          'Şifa Kiralık Takip',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Ara',
            onPressed: () => _push(const GlobalSearchScreen()),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: _syncLabel(),
            onPressed: syncStatus.online && runtime?.updateRequired != true
                ? sync.syncNow
                : null,
            icon: Badge(
              isLabelVisible:
                  syncStatus.pending > 0 || syncStatus.conflicts > 0,
              label: Text(
                '${syncStatus.conflicts > 0 ? syncStatus.conflicts : syncStatus.pending}',
              ),
              child: Icon(_syncIcon()),
            ),
          ),
          IconButton(
            tooltip: 'Hatırlatmalar',
            onPressed: () => _push(const ReminderCenterScreen()),
            icon: Badge(
              isLabelVisible: syncStatus.reminders > 0,
              label: Text('${syncStatus.reminders}'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          const SizedBox(width: 4),
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
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _showQuickActions,
              icon: const Icon(Icons.add),
              label: const Text('Yeni İşlem'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) {
          setState(() => index = value);
        },
        destinations: items.map((e) => e.destination).toList(),
      ),
    );
  }

  Future<void> _showQuickActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Yeni İşlem',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                icon: Icons.local_shipping_outlined,
                title: 'Yeni Kiralama / Malzeme Gönder',
                subtitle: 'Müşteriyi seç, malzemeleri ve ilk fiyatları gir.',
                onTap: () {
                  Navigator.pop(context);
                  _push(const ShipmentScreen());
                },
              ),
              _QuickActionTile(
                icon: Icons.keyboard_return,
                title: 'Malzeme Geri Al',
                subtitle: 'Aktif kiralamayı seçip iade hareketi ekle.',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => index = 1);
                },
              ),
              if (role == AppRole.admin)
                _QuickActionTile(
                  icon: Icons.payments_outlined,
                  title: 'Ödeme / Tahsilat',
                  subtitle: 'Açık hesapları görüntüle ve tahsilatı işle.',
                  onTap: () {
                    Navigator.pop(context);
                    _push(const ReceivablesScreen());
                  },
                ),
            ],
          ),
        ),
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
    if (syncStatus.conflicts > 0) return Icons.sync_problem_outlined;
    if (syncStatus.pending > 0) return Icons.cloud_upload_outlined;
    return Icons.cloud_done_outlined;
  }

  String _syncLabel() {
    if (runtime?.updateRequired == true) return 'Güncelleme gerekli';
    if (!syncStatus.online) return 'Offline';
    if (syncStatus.syncing) return 'Senkronize ediliyor';
    if (syncStatus.error != null) return 'Senkron hatası';
    if (syncStatus.conflicts > 0) {
      return '${syncStatus.conflicts} çakışma';
    }
    if (syncStatus.pending > 0) {
      return '${syncStatus.pending} işlem bekliyor';
    }
    return 'Güncel';
  }
}

class _MorePage extends StatelessWidget {
  final AppRole role;
  final bool readOnly;
  final AutoSyncStatus syncStatus;
  final void Function(Widget page) onOpen;
  final Future<void> Function() onRefreshRuntime;
  final Future<void> Function() onServerSettings;
  final Future<void> Function() onLogout;

  const _MorePage({
    required this.role,
    required this.readOnly,
    required this.syncStatus,
    required this.onOpen,
    required this.onRefreshRuntime,
    required this.onServerSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final canWrite = role != AppRole.viewer && !readOnly;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        Text(
          'Daha Fazla',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Günlük akışın dışında kalan araçlar burada.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        _sectionTitle(context, 'İşlemler'),
        _MenuCard(
          children: [
            _MenuTile(
              icon: Icons.inventory_2_outlined,
              title: 'Malzemeler',
              onTap: () => onOpen(const MaterialsScreen()),
            ),
            if (canWrite)
              _MenuTile(
                icon: Icons.fact_check_outlined,
                title: 'Stok Sayımı',
                onTap: () => onOpen(const StockCountScreen()),
              ),
            if (canWrite)
              _MenuTile(
                icon: Icons.warehouse_outlined,
                title: 'Stok Bakımı',
                onTap: () => onOpen(const StockMaintenanceScreen()),
              ),
            if (canWrite)
              _MenuTile(
                icon: Icons.add_box_outlined,
                title: 'Stok Girişi',
                onTap: () => onOpen(const StockSourceScreen()),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(context, 'Takip ve Rapor'),
        _MenuCard(
          children: [
            _MenuTile(
              icon: Icons.notifications_outlined,
              title: 'Hatırlatmalar',
              trailing: syncStatus.reminders > 0
                  ? '${syncStatus.reminders}'
                  : null,
              onTap: () => onOpen(const ReminderCenterScreen()),
            ),
            if (syncStatus.conflicts > 0)
              _MenuTile(
                icon: Icons.sync_problem_outlined,
                title: 'Senkron Çakışmaları',
                trailing: '${syncStatus.conflicts}',
                onTap: () => onOpen(const ConflictResolutionScreen()),
              ),
            if (role != AppRole.viewer)
              _MenuTile(
                icon: Icons.assessment_outlined,
                title: 'Raporlar',
                onTap: () => onOpen(const ReportsScreen()),
              ),
            _MenuTile(
              icon: Icons.search,
              title: 'Genel Arama',
              onTap: () => onOpen(const GlobalSearchScreen()),
            ),
          ],
        ),
        if (role == AppRole.admin) ...[
          const SizedBox(height: 16),
          _sectionTitle(context, 'Yönetim'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Yönetim Merkezi',
                onTap: () => onOpen(const AdminHubScreen()),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _sectionTitle(context, 'Sistem'),
        _MenuCard(
          children: [
            _MenuTile(
              icon: Icons.refresh,
              title: 'Sunucu Durumunu Yenile',
              onTap: onRefreshRuntime,
            ),
            _MenuTile(
              icon: Icons.settings_ethernet,
              title: 'Sunucu Adresini Değiştir',
              onTap: onServerSettings,
            ),
            _MenuTile(
              icon: Icons.logout,
              title: 'Çıkış Yap',
              onTap: onLogout,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            '${_roleLabel(role)} • v${AppVersion.current}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      );

  String _roleLabel(AppRole value) => switch (value) {
        AppRole.admin => 'Admin',
        AppRole.staff => 'Personel',
        AppRole.viewer => 'Görüntüleyici',
      };
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final FutureOr<void> Function() onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: trailing == null
          ? const Icon(Icons.chevron_right)
          : Badge(
              label: Text(trailing!),
              child: const Icon(Icons.chevron_right),
            ),
      onTap: () => onTap(),
    );
  }
}

class _NavItem {
  final Widget page;
  final NavigationDestination destination;

  const _NavItem({
    required this.page,
    required this.destination,
  });
}
