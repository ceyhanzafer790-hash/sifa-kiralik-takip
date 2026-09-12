import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';
import '../services/diagnostics_download_service.dart';

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  final repo = AdminApiRepository();
  final diagnostics = DiagnosticsDownloadService();
  Map<String, dynamic>? health;
  String? error;
  bool loading = true;

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
      final data = await repo.systemHealth();
      if (mounted) setState(() => health = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> _downloadDiagnostics() async {
    try {
      final path = await diagnostics.download();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Teşhis Paketi Hazır'),
          content: SelectableText(
            '$path\n\n'
            'Paket; DATABASE_URL, JWT, parola, belge içeriği ve '
            'istemci IP bilgisi içermez.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Teşhis paketi alınamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = health;
    final db = _map(h?['database']);
    final pool = _map(db['pool']);
    final queryTiming = _map(db['query_timing']);
    final storage = _map(h?['storage']);
    final documentDisk = _map(storage['documents']);
    final backup = _map(h?['backup']);
    final migration = _map(h?['migrations']);
    final usage = _map(h?['usage']);

    return Scaffold(
      appBar: AppBar(title: const Text('Sistem Durumu')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(error!),
                ),
              ),
            if (h != null) ...[
              _HealthCard(
                title: 'Genel Durum',
                level: h['overall']?.toString() ?? 'warning',
                value: _levelLabel(h['overall']?.toString()),
                subtitle: 'API çalışma süresi: '
                    '${_duration((h['api_uptime_seconds'] as num?)?.toInt() ?? 0)}',
              ),
              _HealthCard(
                title: 'PostgreSQL',
                level: db['status']?.toString() ?? 'warning',
                value: _bytes((db['size_bytes'] as num?)?.toInt() ?? 0),
                subtitle:
                    'Pool: ${pool['pool_size'] ?? "-"} bağlantı • '
                    'Bekleyen: ${pool['requests_waiting'] ?? 0}',
              ),
              _HealthCard(
                title: 'Yavaş SQL',
                level:
                    ((queryTiming['slow_query_count'] as num?)?.toInt() ?? 0) > 0
                        ? 'warning'
                        : 'ok',
                value:
                    '${queryTiming['slow_query_count'] ?? 0} yavaş sorgu',
                subtitle:
                    'Toplam ${queryTiming['query_count'] ?? 0} sorgu • '
                    'Eşik ${queryTiming['slow_query_threshold_ms'] ?? 500} ms • '
                    'En uzun ${queryTiming['max_query_ms'] ?? 0} ms',
              ),
              _HealthCard(
                title: 'Belge Diski',
                level: documentDisk['level']?.toString() ?? 'warning',
                value:
                    '%${documentDisk['free_percent'] ?? "-"} boş',
                subtitle:
                    '${storage['document_file_count'] ?? 0} kayıtlı belge • '
                    '${_bytes((storage['document_registered_bytes'] as num?)?.toInt() ?? 0)}',
              ),
              _HealthCard(
                title: 'Yedek',
                level: backup['level']?.toString() ?? 'warning',
                value:
                    'Yerel ${backup['local_backup_age_hours'] ?? "-"} saat',
                subtitle:
                    'OneDrive ${backup['cloud_backup_age_hours'] ?? "-"} saat önce',
              ),
              _HealthCard(
                title: 'Veritabanı Migration',
                level:
                    ((migration['checksum_errors'] as List?)?.isNotEmpty == true)
                        ? 'critical'
                        : ((migration['pending'] as List?)?.isNotEmpty == true)
                            ? 'warning'
                            : 'ok',
                value:
                    '${migration['latest_applied'] ?? "-"} / '
                    '${migration['latest_available'] ?? "-"}',
                subtitle:
                    '${(migration['pending'] as List?)?.length ?? 0} bekleyen migration',
              ),
              _HealthCard(
                title: 'Kullanım',
                level: 'ok',
                value: '${usage['active_rentals'] ?? 0} aktif kiralama',
                subtitle:
                    '${usage['active_users'] ?? 0} aktif kullanıcı • '
                    '${usage['total_rentals'] ?? 0} toplam kiralama',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _downloadDiagnostics,
                icon: const Icon(Icons.bug_report_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('TEŞHİS PAKETİ OLUŞTUR'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  String _bytes(int value) {
    if (value >= 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (value >= 1024) {
      return '${(value / 1024).toStringAsFixed(1)} KB';
    }
    return '$value B';
  }

  String _duration(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    if (days > 0) return '$days gün $hours saat';
    final minutes = (seconds % 3600) ~/ 60;
    return '$hours saat $minutes dk';
  }

  String _levelLabel(String? level) => switch (level) {
        'ok' => 'Sağlıklı',
        'critical' => 'Kritik',
        _ => 'Kontrol gerekli',
      };
}

class _HealthCard extends StatelessWidget {
  final String title;
  final String level;
  final String value;
  final String subtitle;

  const _HealthCard({
    required this.title,
    required this.level,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (level) {
      'ok' => Icons.check_circle_outline,
      'critical' => Icons.error_outline,
      _ => Icons.warning_amber_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(subtitle),
          trailing: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
