import 'package:flutter/material.dart';

import '../services/role_service.dart';
import 'admin_users_screen.dart';
import 'audit_log_screen.dart';
import 'backup_status_screen.dart';
import 'legacy_import_screen.dart';
import 'system_status_screen.dart';
import 'document_compliance_screen.dart';
import 'app_maintenance_screen.dart';
import 'release_packages_screen.dart';
import 'production_readiness_screen.dart';

class AdminHubScreen extends StatefulWidget {
  const AdminHubScreen({super.key});

  @override
  State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> {
  final roles = RoleService();
  bool? isAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await roles.isAdmin();
    if (mounted) setState(() => isAdmin = value);
  }

  @override
  Widget build(BuildContext context) {
    if (isAdmin == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isAdmin == false) {
      return const Center(
        child: Text('Bu bölüm yalnızca yönetici hesabına açık.'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Yönetim',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text(
              'Kullanıcı Yönetimi',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Personel ekle, rol değiştir, hesabı pasif yap, şifre yenile.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminUsersScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text(
              'Sistem Durumu',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Veritabanı migration sürümü ve yedek durumunu birlikte kontrol et.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SystemStatusScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: ListTile(
            leading: const Icon(Icons.system_update_alt_outlined),
            title: const Text(
              'Bakım ve Sürüm Yönetimi',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Bakım modu, minimum desteklenen sürüm ve güncel sürüm ayarları.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AppMaintenanceScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_outlined),
            title: const Text(
              'Sürüm Paketleri',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Android/Windows/iOS build dosyalarının SHA-256 ve sürüm kayıtları.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReleasePackagesScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Card(
          child: ListTile(
            leading: const Icon(Icons.rocket_launch_outlined),
            title: const Text(
              'Üretime Hazırlık',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Migration, yedek, güvenlik, release paketleri ve temel kurulum kontrolleri.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ProductionReadinessScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: const Text(
              'Yedek Sağlığı',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Yerel ve OneDrive yedeklerinin son başarılı zamanını gör.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BackupStatusScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text(
              'Eksik Belgeler',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Eksik kira sözleşmesi, giden sevkiyat ve iade belgelerini kontrol et.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DocumentComplianceScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.rule_folder_outlined),
            title: const Text('Eski Veri Eşleştirme', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Eski sözleşme ve sevkiyat belgelerini doğru kayda bağla.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LegacyImportScreen())),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text(
              'İşlem Geçmişi',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Kim hangi kaydı ne zaman değiştirmiş incele.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AuditLogScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
