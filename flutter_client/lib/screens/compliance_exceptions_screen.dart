import 'package:flutter/material.dart';

import '../services/document_compliance_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

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
      appBar: AppBar(
        title: const Text(
          'Belge İstisnaları',
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
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
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
                            'Eski arşivde doğrulanmış belgeler için verilmiş istisnaları yönet.',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Aktif istisna',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusPill(
                          label: '${rows.length}',
                          tone: rows.isEmpty
                              ? AppStatusTone.success
                              : AppStatusTone.info,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ],
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
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: SifaBrand.infoBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.verified_outlined,
                      color: SifaBrand.info,
                    ),
                  ),
                  title: Text(_label(r['document_type']?.toString())),
                  subtitle: Text(
                    '${r['reason']}\n'
                    'Ekleyen: ${r['created_by_name'] ?? "-"}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'İstisnayı geri al',
                    onPressed: () => _revoke(r),
                    icon: const Icon(
                      Icons.undo,
                      color: SifaBrand.deepGold,
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

  String _label(String? type) => switch (type) {
        'contract' => 'Kira sözleşmesi',
        'outbound_delivery' => 'Giden sevkiyat belgesi',
        'inbound_delivery' => 'Gelen/iade belgesi',
        _ => type ?? 'Belge',
      };
}
