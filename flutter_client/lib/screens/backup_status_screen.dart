import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';
import '../widgets/sifa_brand.dart';

class BackupStatusScreen extends StatefulWidget {
  const BackupStatusScreen({super.key});

  @override
  State<BackupStatusScreen> createState() => _BackupStatusScreenState();
}

class _BackupStatusScreenState extends State<BackupStatusScreen> {
  final repo = AdminApiRepository();
  Map<String, dynamic>? status;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await repo.backupStatus();
      if (mounted) setState(() => status = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = status;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yedek Sağlığı',
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: SifaBrand.charcoal,
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                child: const Row(
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      color: SifaBrand.gold,
                      size: 28,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yedek Kontrolü',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Yerel, bulut ve felaket kurtarma yedeklerini izle.',
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
            if (loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(error!),
                ),
              ),
            if (s != null) ...[
              _StatusCard(
                title: 'Yerel Yedek',
                ok: s['local_backup_ok'] == true,
                time: s['local_backup_at']?.toString(),
              ),
              const SizedBox(height: 8),
              _StatusCard(
                title: 'OneDrive Şifreli Yedek',
                ok: s['cloud_backup_ok'] == true,
                time: s['cloud_backup_at']?.toString(),
              ),
              const SizedBox(height: 8),
              _StatusCard(
                title: 'Felaket Kurtarma Paketi',
                ok: s['disaster_export_ok'] == true,
                time: s['disaster_export_at']?.toString(),
              ),
              if (s['disaster_export_file'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(
                    'Dosya: ${s['disaster_export_file']}',
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    s['message']?.toString() ??
                        'Yedekler otomatik oluşturulur. '
                        'Geri yükleme testi sunucuda ayrıca yapılır.',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final bool ok;
  final String? time;

  const _StatusCard({
    required this.title,
    required this.ok,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        ok ? SifaBrand.success : const Color(0xFF9A5D00);
    final background =
        ok ? SifaBrand.successBg : const Color(0xFFFFF4E5);

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: foreground,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          time == null
              ? 'Henüz doğrulanmış yedek yok'
              : 'Son başarılı: $time',
        ),
      ),
    );
  }
}
