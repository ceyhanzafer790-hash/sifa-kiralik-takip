import 'package:flutter/material.dart';

import '../services/admin_api_repository.dart';
import '../widgets/sifa_brand.dart';

class ReleasePackagesScreen extends StatefulWidget {
  const ReleasePackagesScreen({super.key});

  @override
  State<ReleasePackagesScreen> createState() =>
      _ReleasePackagesScreenState();
}

class _ReleasePackagesScreenState
    extends State<ReleasePackagesScreen> {
  final repo = AdminApiRepository();

  List<Map<String, dynamic>> rows = [];
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
      final data = await repo.releases();
      if (mounted) setState(() => rows = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deactivate(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sürüm Paketini Pasifleştir'),
        content: Text(
          '${row['platform']} • ${row['version']}\n'
          '${row['file_name']}\n\n'
          'Bu işlem dosyayı silmez; güncel manifestten çıkarır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pasifleştir'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await repo.deactivateRelease(row['id'].toString());
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem başarısız: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sürüm Paketleri',
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
                      Icons.verified_outlined,
                      color: SifaBrand.gold,
                      size: 27,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Android, Windows ve iOS paketlerinin sürüm, boyut ve SHA-256 kayıtları.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(error!),
                ),
              ),
            if (!loading && rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Henüz gerçek build paketi kayıtlı değil. '
                    'Bilgisayarda ilk APK/Windows build sonrası oluşacak.',
                  ),
                ),
              ),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: SifaBrand.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _platformIcon(r['platform']?.toString()),
                        color: SifaBrand.deepGold,
                      ),
                    ),
                    title: Text(
                      '${r['platform']} • v${r['version']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: SelectableText(
                      '${r['file_name']}\n'
                      '${_bytes((r['size_bytes'] as num?)?.toInt() ?? 0)}\n'
                      'SHA-256: ${r['sha256']}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'deactivate') {
                          _deactivate(r);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'deactivate',
                          child: Text('Pasifleştir'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _platformIcon(String? platform) => switch (platform) {
        'android' => Icons.android,
        'windows' => Icons.desktop_windows_outlined,
        'ios' => Icons.phone_iphone,
        _ => Icons.inventory_2_outlined,
      };

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
}
