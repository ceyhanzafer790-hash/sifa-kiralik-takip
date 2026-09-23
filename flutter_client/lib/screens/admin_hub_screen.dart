import 'package:flutter/material.dart';

import '../services/role_service.dart';
import '../widgets/sifa_brand.dart';
import 'admin_users_screen.dart';
import 'app_maintenance_screen.dart';
import 'audit_log_screen.dart';
import 'backup_status_screen.dart';
import 'document_compliance_screen.dart';
import 'legacy_import_screen.dart';
import 'production_readiness_screen.dart';
import 'release_packages_screen.dart';
import 'system_status_screen.dart';

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

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yönetim Merkezi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: SifaBrand.gold,
          ),
        ),
      ),
      body: isAdmin == null
          ? const Center(child: CircularProgressIndicator())
          : isAdmin == false
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Bu bölüm yalnızca yönetici hesabına açık.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        color: SifaBrand.charcoal,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: SifaBrand.gold,
                              size: 28,
                            ),
                            SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ŞİFA Yönetim Merkezi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Kullanıcı, sistem, sürüm ve denetim işlemleri.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle(context, 'Erişim ve Kullanıcılar'),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Kullanıcı Yönetimi',
                      subtitle:
                          'Personel ekle, rol değiştir, hesabı pasif yap ve şifre yenile.',
                      onTap: () => _open(const AdminUsersScreen()),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle(context, 'Sistem ve Sürüm'),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.monitor_heart_outlined,
                      title: 'Sistem Durumu',
                      subtitle:
                          'Veritabanı, disk, sorgular, migration ve kullanım durumunu kontrol et.',
                      onTap: () => _open(const SystemStatusScreen()),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.system_update_alt_outlined,
                      title: 'Bakım ve Sürüm Yönetimi',
                      subtitle:
                          'Bakım modu, minimum desteklenen sürüm ve güncel sürüm ayarları.',
                      onTap: () => _open(const AppMaintenanceScreen()),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.verified_outlined,
                      title: 'Sürüm Paketleri',
                      subtitle:
                          'Android, Windows ve iOS build dosyalarının sürüm kayıtları.',
                      onTap: () => _open(const ReleasePackagesScreen()),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.rocket_launch_outlined,
                      title: 'Üretime Hazırlık',
                      subtitle:
                          'Migration, yedek, güvenlik ve temel kurulum kontrolleri.',
                      onTap: () => _open(const ProductionReadinessScreen()),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle(context, 'Yedek ve Belgeler'),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.health_and_safety_outlined,
                      title: 'Yedek Sağlığı',
                      subtitle:
                          'Yerel ve OneDrive yedeklerinin son başarılı zamanını gör.',
                      onTap: () => _open(const BackupStatusScreen()),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Eksik Belgeler',
                      subtitle:
                          'Eksik sözleşme, giden sevkiyat ve iade belgelerini kontrol et.',
                      onTap: () => _open(const DocumentComplianceScreen()),
                    ),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.rule_folder_outlined,
                      title: 'Eski Veri Eşleştirme',
                      subtitle:
                          'Eski sözleşme ve sevkiyat belgelerini doğru kayda bağla.',
                      onTap: () => _open(const LegacyImportScreen()),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle(context, 'Denetim'),
                    const SizedBox(height: 8),
                    _AdminMenuCard(
                      icon: Icons.history_outlined,
                      title: 'İşlem Geçmişi',
                      subtitle:
                          'Kim hangi kaydı ne zaman değiştirmiş incele.',
                      onTap: () => _open(const AuditLogScreen()),
                    ),
                  ],
                ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      );
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SifaBrand.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: SifaBrand.deepGold,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
          color: SifaBrand.deepGold,
        ),
        onTap: onTap,
      ),
    );
  }
}
