import 'package:flutter/material.dart';

import '../services/document_compliance_repository.dart';

class ComplianceExceptionsScreen extends StatefulWidget {
  const ComplianceExceptionsScreen({super.key});

  @override
  State<ComplianceExceptionsScreen> createState() =>
      _ComplianceExceptionsScreenState();
}

class _ComplianceExceptionsScreenState
    extends State<ComplianceExceptionsScreen> {
  final repo = DocumentComplianceRepository();

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
      final result = await repo.exceptions();
      if (mounted) setState(() => rows = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İstisnayı Geri Al'),
        content: Text(
          'Bu belge tekrar eksik olarak kontrol edilecek.\n\n'
          'Gerekçe: ${row['reason']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Geri Al'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await repo.revokeException(row['id'].toString());
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belge İstisnaları')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Buradaki kayıtlar belge silmez. Sadece eski arşivde '
                  'doğrulanmış belge için eksik-belge alarmını istisna eder.',
                ),
              ),
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (!loading && rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aktif belge istisnası yok.'),
                ),
              ),
            ...rows.map(
              (r) => Card(
                child: ListTile(
                  leading: const Icon(Icons.verified_outlined),
                  title: Text(_label(r['document_type']?.toString())),
                  subtitle: Text(
                    '${r['reason']}\n'
                    'Ekleyen: ${r['created_by_name'] ?? "-"}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'İstisnayı geri al',
                    onPressed: () => _revoke(r),
                    icon: const Icon(Icons.undo),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String? type) => switch (type) {
        'contract' => 'Kira sözleşmesi',
        'outbound_delivery' => 'Giden sevkiyat belgesi',
        'inbound_delivery' => 'Gelen/iade belgesi',
        _ => type ?? 'Belge',
      };
}
