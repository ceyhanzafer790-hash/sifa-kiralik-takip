import 'package:flutter/material.dart';

import '../services/document_compliance_repository.dart';
import '../services/role_service.dart';
import '../widgets/sifa_brand.dart';
import 'compliance_exceptions_screen.dart';
import 'rental_tracking_detail_screen.dart';

class DocumentComplianceScreen extends StatefulWidget {
  const DocumentComplianceScreen({super.key});

  @override
  State<DocumentComplianceScreen> createState() =>
      _DocumentComplianceScreenState();
}

class _DocumentComplianceScreenState
    extends State<DocumentComplianceScreen> {
  final repo = DocumentComplianceRepository();
  final roles = RoleService();

  List<Map<String, dynamic>> rows = [];
  bool loading = true;
  bool isAdmin = false;
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
      final result = await Future.wait([
        repo.missing(),
        roles.isAdmin(),
      ]);

      if (mounted) {
        setState(() {
          rows = result[0] as List<Map<String, dynamic>>;
          isAdmin = result[1] as bool;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _exception(
    Map<String, dynamic> rental,
    Map<String, dynamic> item,
  ) async {
    final controller = TextEditingController(
      text: 'Eski fiziksel arşivde doğrulandı.',
    );

    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Belge İstisnası'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${rental['customer_name']} • ${item['label']}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Bu işlem belge yüklemez. Eksik alarmını gerekçeli olarak '
              'istisna eder ve işlem geçmişine yazılır.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Gerekçe',
                prefixIcon: Icon(
                  Icons.rule_outlined,
                  color: SifaBrand.deepGold,
                ),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 3) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('İstisna Ver'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (reason == null) return;

    try {
      await repo.createException(
        rentalId: rental['rental_record_id'].toString(),
        movementId: item['movement_id']?.toString(),
        documentType: item['document_type'].toString(),
        reason: reason,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İstisna kaydedilemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final missingTotal = rows.fold<int>(
      0,
      (sum, r) => sum + ((r['missing_total'] as num?)?.toInt() ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Eksik Belgeler',
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
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Belge istisnaları',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ComplianceExceptionsScreen(),
                  ),
                );
                await _load();
              },
              icon: const Icon(Icons.verified_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: missingTotal > 0
                      ? const Color(0xFFFFF4E5)
                      : SifaBrand.successBg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      missingTotal > 0
                          ? Icons.warning_amber_outlined
                          : Icons.verified_outlined,
                      color: missingTotal > 0
                          ? const Color(0xFF9A5D00)
                          : SifaBrand.success,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        loading
                            ? 'Belgeler kontrol ediliyor…'
                            : missingTotal > 0
                                ? 'Toplam $missingTotal eksik belge veya bağlantı var.'
                                : 'Eksik belge görünmüyor.',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (!loading && rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aktif kayıtlarda eksik kira sözleşmesi veya '
                    'sevkiyat/iade belgesi görünmüyor.',
                  ),
                ),
              ),
            ...rows.map(
              (row) {
                final items = ((row['missing_items'] as List?) ?? const [])
                    .map(
                      (e) => Map<String, dynamic>.from(e as Map),
                    )
                    .toList();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.description_outlined),
                            title: Text(
                              row['customer_name']?.toString() ??
                                  'Müşteri',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              row['address_label']?.toString() ??
                                  'Şantiye seçilmedi',
                            ),
                            trailing: IconButton(
                              tooltip: 'Kiralama Takibi aç',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RentalTrackingDetailScreen(
                                    recordId:
                                        row['rental_record_id'].toString(),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ),
                          const Divider(),
                          ...items.map(
                            (item) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.warning_amber_outlined,
                                size: 20,
                              ),
                              title: Text(item['label'].toString()),
                              subtitle: item['movement_date'] == null
                                  ? null
                                  : Text(
                                      '${item['movement_date']}'
                                      '${item['quantity'] == null ? "" : " • ${item['quantity']}"}',
                                    ),
                              trailing: isAdmin
                                  ? TextButton(
                                      onPressed: () =>
                                          _exception(row, item),
                                      child:
                                          const Text('İstisna Ver'),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
