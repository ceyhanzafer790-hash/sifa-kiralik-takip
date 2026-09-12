import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/api_config.dart';
import '../services/role_service.dart';
import '../services/stock_api_repository.dart';

class StockMaintenanceScreen extends StatefulWidget {
  const StockMaintenanceScreen({super.key});

  @override
  State<StockMaintenanceScreen> createState() =>
      _StockMaintenanceScreenState();
}

class _StockMaintenanceScreenState extends State<StockMaintenanceScreen> {
  final repo = StockApiRepository();
  final roleService = RoleService();
  final uuid = const Uuid();

  Product? selected;
  Map<String, dynamic>? summary;
  bool canWrite = false;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final allowed = await roleService.canWrite();
    if (mounted) setState(() => canWrite = allowed);
  }

  Future<void> _loadSummary() async {
    final p = selected;
    if (p == null || !ApiConfig.configured) return;

    setState(() => loading = true);
    try {
      final data = await repo.productSummary(p.id);
      if (mounted) setState(() => summary = data);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<double?> _askQuantity(String title, String helper) async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: helper,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _repairComplete() async {
    final p = selected;
    if (p == null || !canWrite || !ApiConfig.configured) return;

    final qty = await _askQuantity(
      'Tamirden Çıktı',
      'Kullanılabilir stoğa dönecek miktar',
    );
    if (qty == null) return;

    await repo.repairComplete({
      'product_id': p.id,
      'quantity': qty,
      'movement_date': _date(DateTime.now()),
      'client_operation_id': uuid.v4(),
    });

    await _loadSummary();
  }

  Future<void> _writeOff(String reason) async {
    final p = selected;
    if (p == null || !canWrite || !ApiConfig.configured) return;

    final qty = await _askQuantity(
      reason == 'scrap' ? 'Hurdaya Ayır' : 'Kayıp Gir',
      'Miktar',
    );
    if (qty == null) return;

    await repo.writeOff({
      'product_id': p.id,
      'quantity': qty,
      'movement_date': _date(DateTime.now()),
      'reason': reason,
      'source_bucket': 'available',
      'client_operation_id': uuid.v4(),
    });

    await _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final p = selected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Stok Durum Yönetimi',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tamirlik, hurda ve kayıp miktarlar kullanılabilir stoktan ayrı tutulur.',
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Product>(
          value: selected,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Malzeme',
            border: OutlineInputBorder(),
          ),
          items: products
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              selected = value;
              summary = null;
            });
            _loadSummary();
          },
        ),
        if (loading) const LinearProgressIndicator(),
        if (p != null && summary != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _BucketCard(
                title: 'Kullanılabilir',
                value: summary!['available'],
                unit: p.unit.label,
              ),
              _BucketCard(
                title: 'Tamirlik',
                value: summary!['repair'],
                unit: p.unit.label,
              ),
              _BucketCard(
                title: 'Hurda',
                value: summary!['scrap'],
                unit: p.unit.label,
              ),
              _BucketCard(
                title: 'Kayıp',
                value: summary!['lost'],
                unit: p.unit.label,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!canWrite)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Bu hesap sadece görüntüleme yetkisine sahip.',
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _repairComplete,
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Tamirden Çıktı'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _writeOff('scrap'),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Hurdaya Ayır'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _writeOff('lost'),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Kayıp Gir'),
                ),
              ],
            ),
        ],
      ],
    );
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _BucketCard extends StatelessWidget {
  final String title;
  final dynamic value;
  final String unit;

  const _BucketCard({
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 6),
              Text(
                '${value ?? 0} $unit',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
