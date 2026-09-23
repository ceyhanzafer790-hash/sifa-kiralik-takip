import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/api_config.dart';
import '../services/offline_sync_service.dart';
import '../services/role_service.dart';
import '../services/stock_api_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

enum _CountMode {
  direct,
  package,
}

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
  bool saving = false;
  _CountMode mode = _CountMode.direct;

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
    if (mode == _CountMode.direct) {
      return double.tryParse(
            directController.text.replaceAll(',', '.'),
          ) ??
          0;
    }

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
    } catch (_) {
      if (mounted) setState(() => summary = null);
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

    setState(() => saving = true);

    final operationId = uuid.v4();
    final payload = {
      'counted_at': _date(DateTime.now()),
      'note': 'Mobil hızlı sayım',
      'items': [
        {
          'product_id': product.id,
          'counted_quantity': qty,
          'package_count': mode == _CountMode.package
              ? double.tryParse(
                  packageController.text.replaceAll(',', '.'),
                )
              : null,
          'loose_quantity': mode == _CountMode.package
              ? double.tryParse(
                  looseController.text.replaceAll(',', '.'),
                )
              : null,
        },
      ],
    };

    try {
      if (ApiConfig.configured) {
        try {
          await repo.createCount({
            ...payload,
            'client_operation_id': operationId,
          });
          if (mounted) {
            _message('Fiziksel sayım kaydedildi.');
          }
          await _loadSummary();
          return;
        } catch (_) {
          // Ağ yoksa aşağıdaki kalıcı kuyruğa girer.
        }
      }

      await queue.enqueueWithId(
        operationId,
        SyncOperationType.createStockCount,
        payload,
      );

      if (mounted) {
        _message(
          'Sayım telefona kaydedildi. İnternet gelince merkeze gönderilecek.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _selectProduct(Product? value) {
    setState(() {
      selected = value;
      summary = null;
      directController.clear();
      packageController.clear();
      looseController.clear();
      packageSizeController.text =
          value?.packSize?.toString() ?? '';
      mode = _CountMode.direct;
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final product = selected;
    final systemAvailable = _value(summary?['available']);
    final difference = countedQuantity - systemAvailable;
    final hasCountInput = mode == _CountMode.direct
        ? directController.text.trim().isNotEmpty
        : packageController.text.trim().isNotEmpty ||
            looseController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Depo Sayımı',
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
      body: ListView(
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
                        Icons.fact_check_outlined,
                        color: SifaBrand.gold,
                        size: 28,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hızlı Fiziksel Sayım',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Tek malzemeyi say, sistem stoğuyla farkı hemen gör.',
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
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        color: SifaBrand.deepGold,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'İnternet yoksa sayım cihazda kuyruğa alınır.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<Product>(
            value: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sayılacak Malzeme',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: products
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.name),
                  ),
                )
                .toList(),
            onChanged: _selectProduct,
          ),
          if (loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (product != null) ...[
            const SizedBox(height: 14),
            if (summary != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CountMetric(
                          label: 'Sistem Stoğu',
                          value: systemAvailable,
                          unit: product.unit.label,
                          icon: Icons.warehouse_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        label: summary!['confidence'] == 'counted'
                            ? 'Sayım bazlı'
                            : 'Tahmini',
                        tone: summary!['confidence'] == 'counted'
                            ? AppStatusTone.success
                            : AppStatusTone.warning,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              )
            else if (!loading)
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF9A5D00),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sistem stok özeti alınamadı. Fiziksel sayım yine kaydedilebilir.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            SegmentedButton<_CountMode>(
              segments: const [
                ButtonSegment(
                  value: _CountMode.direct,
                  icon: Icon(Icons.pin_outlined),
                  label: Text('Doğrudan'),
                ),
                ButtonSegment(
                  value: _CountMode.package,
                  icon: Icon(Icons.inventory_outlined),
                  label: Text('Paket + Açık'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (value) {
                setState(() => mode = value.first);
              },
            ),
            const SizedBox(height: 12),
            if (mode == _CountMode.direct)
              TextField(
                controller: directController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Saydığın miktar',
                  suffixText: product.unit.label,
                  prefixIcon: const Icon(Icons.numbers_outlined),
                ),
                onChanged: (_) => setState(() {}),
              )
            else ...[
              TextField(
                controller: packageSizeController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '1 paket / bağ kaç ${product.unit.label}?',
                  prefixIcon: const Icon(Icons.inventory_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: packageController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Tam paket / bağ',
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
                      decoration: InputDecoration(
                        labelText: 'Açık / tek',
                        suffixText: product.unit.label,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _CountMetric(
                            label: 'Sayım Sonucu',
                            value: countedQuantity,
                            unit: product.unit.label,
                            icon: Icons.fact_check_outlined,
                            emphasize: true,
                          ),
                        ),
                        if (summary != null && hasCountInput) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _CountMetric(
                              label: 'Fark',
                              value: difference,
                              unit: product.unit.label,
                              icon: difference == 0
                                  ? Icons.check_circle_outline
                                  : Icons.compare_arrows,
                              warning: difference != 0,
                              signed: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (summary != null && hasCountInput) ...[
                      const SizedBox(height: 10),
                      Text(
                        difference == 0
                            ? 'Fiziksel sayım sistem stoğuyla aynı.'
                            : difference > 0
                                ? 'Depoda sistemden ${_number(difference)} ${product.unit.label} fazla sayıldı.'
                                : 'Depoda sistemden ${_number(difference.abs())} ${product.unit.label} eksik sayıldı.',
                        style: TextStyle(
                          color: difference == 0
                              ? SifaBrand.success
                              : const Color(0xFF9A5D00),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed:
                  canWrite && hasCountInput && !saving ? _saveCount : null,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: Text(
                saving ? 'Kaydediliyor…' : 'Sayımı Kaydet',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  static double _value(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String _number(double value) {
    final fixed = value.toStringAsFixed(2);
    if (fixed.endsWith('.00')) {
      return fixed.substring(0, fixed.length - 3);
    }
    if (fixed.endsWith('0')) {
      return fixed.substring(0, fixed.length - 1);
    }
    return fixed;
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _CountMetric extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final IconData icon;
  final bool emphasize;
  final bool warning;
  final bool signed;

  const _CountMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.emphasize = false,
    this.warning = false,
    this.signed = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = warning
        ? const Color(0xFF9A5D00)
        : emphasize
            ? SifaBrand.deepGold
            : SifaBrand.charcoal;
    final prefix = signed && value > 0 ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: warning
            ? const Color(0xFFFFF4E5)
            : emphasize
                ? SifaBrand.goldBg
                : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning
              ? const Color(0xFFF1D8AF)
              : emphasize
                  ? SifaBrand.gold.withOpacity(0.35)
                  : SifaBrand.softGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$prefix${_StockCountScreenState._number(value)} $unit',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: SifaBrand.textGrey,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
