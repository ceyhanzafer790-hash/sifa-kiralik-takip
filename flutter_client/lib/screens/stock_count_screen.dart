import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/api_config.dart';
import '../services/offline_sync_service.dart';
import '../services/stock_api_repository.dart';
import '../services/role_service.dart';

class StockCountScreen extends StatefulWidget {
  const StockCountScreen({super.key});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  Product? selected;
  final packageController = TextEditingController();
  final looseController = TextEditingController();
  final directController = TextEditingController();
  final packageSizeController = TextEditingController();
  final repo = StockApiRepository();
  final queue = OfflineSyncService();
  final uuid = const Uuid();
  final roleService = RoleService();

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

  @override
  void dispose() {
    packageController.dispose();
    looseController.dispose();
    directController.dispose();
    packageSizeController.dispose();
    super.dispose();
  }

  double get countedQuantity {
    final direct = double.tryParse(
      directController.text.replaceAll(',', '.'),
    );
    if (direct != null) return direct;

    final packages = double.tryParse(
          packageController.text.replaceAll(',', '.'),
        ) ??
        0;
    final loose = double.tryParse(
          looseController.text.replaceAll(',', '.'),
        ) ??
        0;
    final packageSize = double.tryParse(
          packageSizeController.text.replaceAll(',', '.'),
        ) ??
        selected?.packSize ??
        0;

    return packages * packageSize + loose;
  }

  Future<void> _loadSummary() async {
    final product = selected;
    if (product == null || !ApiConfig.configured) return;

    setState(() => loading = true);
    try {
      final data = await repo.productSummary(product.id);
      if (mounted) setState(() => summary = data);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _saveCount() async {
    if (!canWrite) return;
    final product = selected;
    if (product == null) return;

    final qty = countedQuantity;
    if (qty < 0) return;

    final operationId = uuid.v4();
    final payload = {
      'counted_at': _date(DateTime.now()),
      'note': 'Mobil hızlı sayım',
      'items': [
        {
          'product_id': product.id,
          'counted_quantity': qty,
          'package_count': double.tryParse(
            packageController.text.replaceAll(',', '.'),
          ),
          'loose_quantity': double.tryParse(
            looseController.text.replaceAll(',', '.'),
          ),
        },
      ],
    };

    if (ApiConfig.configured) {
      try {
        await repo.createCount({
          ...payload,
          'client_operation_id': operationId,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fiziksel sayım kaydedildi.')),
          );
        }
        await _loadSummary();
        return;
      } catch (_) {
        // Ağ yoksa aşağıda kalıcı offline kuyruğa girer.
      }
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createStockCount,
      payload,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sayım telefona kaydedildi. İnternet gelince merkeze gönderilecek.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = selected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Depo Sayımı',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tüm depoyu aynı anda saymak zorunda değilsin. '
          'Bir malzemeyi seçip sadece onu sayabilirsin.',
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
              directController.clear();
              packageController.clear();
              looseController.clear();
              packageSizeController.text =
                  value?.packSize?.toString() ?? '';
            });
            _loadSummary();
          },
        ),
        if (loading) const LinearProgressIndicator(),
        if (product != null) ...[
          const SizedBox(height: 16),
          if (summary != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Sistem tahmini depo: ${summary!['available']} ${product.unit.label}\n'
                  'Stok güveni: ${summary!['confidence']}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: directController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Doğrudan sayılan miktar (${product.unit.label})',
              helperText:
                  'İstersen bunu boş bırakıp bağ/paket + açık adet kullan.',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: packageSizeController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '1 bağ / paket kaç ${product.unit.label}?',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: packageController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tam bağ / paket',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: looseController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Açık / tek',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sayım sonucu: ${countedQuantity.toStringAsFixed(countedQuantity % 1 == 0 ? 0 : 2)} '
                '${product.unit.label}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: canWrite ? _saveCount : null,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text('SAYIMI KAYDET'),
            ),
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
