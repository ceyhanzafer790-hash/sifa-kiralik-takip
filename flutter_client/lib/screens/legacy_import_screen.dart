import 'package:flutter/material.dart';

import '../services/legacy_import_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

class LegacyImportScreen extends StatefulWidget {
  const LegacyImportScreen({super.key});

  @override
  State<LegacyImportScreen> createState() => _LegacyImportScreenState();
}

class _LegacyImportScreenState extends State<LegacyImportScreen> {
  final repo = LegacyImportRepository();

  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> customers = [];
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
      final result = await Future.wait([
        repo.pending(),
        repo.customers(),
      ]);

      if (mounted) {
        setState(() {
          items = result[0];
          customers = result[1];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _match(Map<String, dynamic> item) async {
    String? customerId;
    String? rentalId;
    List<Map<String, dynamic>> rentals = [];

    final done = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item['source_file_name'].toString()),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: SifaBrand.goldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Tespit: ${item['detected_customer_name'] ?? 'Müşteri yok'} • '
                      '${item['detected_date'] ?? 'Tarih yok'}',
                      style: const TextStyle(
                        color: SifaBrand.deepGold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: customerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Müşteri',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    items: customers
                        .map(
                          (customer) => DropdownMenuItem(
                            value: customer['id'].toString(),
                            child: Text(customer['name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      customerId = value;
                      rentalId = null;
                      rentals = value == null
                          ? []
                          : await repo.rentals(value);
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: rentalId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Kiralama Takibi',
                      prefixIcon: Icon(Icons.event_repeat_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sadece müşteriye bağla'),
                      ),
                      ...rentals.map(
                        (rental) => DropdownMenuItem<String?>(
                          value: rental['id'].toString(),
                          child: Text(
                            'İlk çıkış: ${rental['original_outbound_date']}',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => rentalId = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () async {
                await repo.match(
                  itemId: item['id'].toString(),
                  status: 'needs_review',
                );
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('İnceleme Beklesin'),
            ),
            FilledButton(
              onPressed: customerId == null
                  ? null
                  : () async {
                      await repo.match(
                        itemId: item['id'].toString(),
                        customerId: customerId,
                        rentalId: rentalId,
                        status: 'matched',
                      );
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
              child: const Text('Eşleştir'),
            ),
          ],
        ),
      ),
    );

    if (done == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Eski Veri Eşleştirme',
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                          Icons.rule_folder_outlined,
                          color: SifaBrand.gold,
                          size: 27,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Eski sözleşme ve sevkiyat belgelerini emin olmadan canlı kayda bağlama.',
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
                            'Eşleştirme bekleyen',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusPill(
                          label: '${items.length}',
                          tone: items.isEmpty
                              ? AppStatusTone.success
                              : AppStatusTone.warning,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!loading && items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 36,
                        color: SifaBrand.success,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Eşleştirme bekleyen kayıt yok.',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: SifaBrand.goldBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.rule_folder_outlined,
                          color: SifaBrand.deepGold,
                        ),
                      ),
                      title: Text(
                        item['source_file_name'].toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        '${item['source_kind']} • '
                        '${item['detected_customer_name'] ?? 'Müşteri tespit edilmedi'}',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: SifaBrand.deepGold,
                      ),
                      onTap: () => _match(item),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
