import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';

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
      appBar: AppBar(title: const Text('Yedek Sağlığı')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(),
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
    return Card(
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
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
