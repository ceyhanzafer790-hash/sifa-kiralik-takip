import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/api_config.dart';
import '../services/role_service.dart';
import '../services/stock_api_repository.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';

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
  bool saving = false;

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
    final product = selected;
    if (product == null || !ApiConfig.configured) return;

    setState(() => loading = true);
    try {
      final data = await repo.productSummary(product.id);
      if (mounted) setState(() => summary = data);
    } catch (e) {
      if (mounted) {
        setState(() => summary = null);
        _message('Stok özeti alınamadı.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<double?> _askQuantity(
    String title,
    String helper, {
    double? maximum,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (maximum != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 11),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: SifaBrand.goldBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Kullanılabilir üst sınır: ${_number(maximum)} '
                    '${selected?.unit.label ?? ''}',
                    style: const TextStyle(
                      color: SifaBrand.deepGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: helper,
                  suffixText: selected?.unit.label,
                ),
              ),
            ],
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
              if (value == null ||
                  value <= 0 ||
                  (maximum != null && value > maximum)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      maximum == null
                          ? 'Geçerli bir miktar gir.'
                          : '0 ile ${_number(maximum)} arasında bir miktar gir.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(context, value);
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
    final product = selected;
    if (!_ready(product)) return;

    final repair = _value(summary?['repair']);
    if (repair <= 0) {
      _message('Tamirlik stokta geri alınacak malzeme yok.');
      return;
    }

    final qty = await _askQuantity(
      'Tamirden Çıktı',
      'Kullanılabilir stoğa dönecek miktar',
      maximum: repair,
    );
    if (qty == null) return;

    await _runAction(() async {
      await repo.repairComplete({
        'product_id': product!.id,
        'quantity': qty,
        'movement_date': _date(DateTime.now()),
        'client_operation_id': uuid.v4(),
      });
      _message('${_number(qty)} ${product.unit.label} kullanılabilir stoğa döndü.');
    });
  }

  Future<void> _writeOff(String reason) async {
    final product = selected;
    if (!_ready(product)) return;

    final available = _value(summary?['available']);
    if (available <= 0) {
      _message('Kullanılabilir stokta işlem yapılacak miktar yok.');
      return;
    }

    final qty = await _askQuantity(
      reason == 'scrap' ? 'Hurdaya Ayır' : 'Kayıp Gir',
      'Miktar',
      maximum: available,
    );
    if (qty == null) return;

    await _runAction(() async {
      await repo.writeOff({
        'product_id': product!.id,
        'quantity': qty,
        'movement_date': _date(DateTime.now()),
        'reason': reason,
        'source_bucket': 'available',
        'client_operation_id': uuid.v4(),
      });
      _message(
        reason == 'scrap'
            ? '${_number(qty)} ${product.unit.label} hurdaya ayrıldı.'
            : '${_number(qty)} ${product.unit.label} kayıp olarak işlendi.',
      );
    });
  }

  bool _ready(Product? product) {
    if (product == null || !canWrite) return false;
    if (!ApiConfig.configured) {
      _message('Bu stok işlemi için sunucu bağlantısı gerekiyor.');
      return false;
    }
    return true;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
      await _loadSummary();
    } catch (e) {
      _message('İşlem kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = selected;
    final connected = ApiConfig.configured;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stok Durum Yönetimi',
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
            child: Container(
              color: SifaBrand.charcoal,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: const Row(
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    color: SifaBrand.gold,
                    size: 28,
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Malzeme Durumu',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Tamirlik, hurda ve kayıp miktarları ayrı yönet.',
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
          ),
          if (!connected) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: Color(0xFF9A5D00),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu durum değişiklikleri şu anda sunucu bağlantısı gerektiriyor.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          DropdownButtonFormField<Product>(
            value: selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Malzeme',
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
            onChanged: (value) {
              setState(() {
                selected = value;
                summary = null;
              });
              _loadSummary();
            },
          ),
          if (loading) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (product != null && summary != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stok Dağılımı',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
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
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _BucketCard(
                  title: 'Kullanılabilir',
                  value: _value(summary!['available']),
                  unit: product.unit.label,
                  icon: Icons.warehouse_outlined,
                  tone: AppStatusTone.success,
                ),
                _BucketCard(
                  title: 'Tamirlik',
                  value: _value(summary!['repair']),
                  unit: product.unit.label,
                  icon: Icons.build_outlined,
                  tone: AppStatusTone.warning,
                ),
                _BucketCard(
                  title: 'Hurda',
                  value: _value(summary!['scrap']),
                  unit: product.unit.label,
                  icon: Icons.delete_sweep_outlined,
                  tone: AppStatusTone.danger,
                ),
                _BucketCard(
                  title: 'Kayıp',
                  value: _value(summary!['lost']),
                  unit: product.unit.label,
                  icon: Icons.help_outline,
                  tone: AppStatusTone.danger,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Durum Değiştir',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 9),
            if (!canWrite)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Bu hesap yalnız görüntüleme yetkisine sahip.',
                  ),
                ),
              )
            else
              Column(
                children: [
                  _ActionCard(
                    icon: Icons.build_circle_outlined,
                    title: 'Tamirden Çıktı',
                    subtitle:
                        'Tamirlik miktarı tekrar kullanılabilir stoğa taşı.',
                    onTap: connected && !saving ? _repairComplete : null,
                  ),
                  const SizedBox(height: 8),
                  _ActionCard(
                    icon: Icons.delete_sweep_outlined,
                    title: 'Hurdaya Ayır',
                    subtitle:
                        'Kullanılabilir stoktan hurdaya miktar aktar.',
                    onTap: connected && !saving
                        ? () => _writeOff('scrap')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  _ActionCard(
                    icon: Icons.help_outline,
                    title: 'Kayıp Gir',
                    subtitle:
                        'Kullanılabilir stoktan kayıp miktar düş.',
                    onTap: connected && !saving
                        ? () => _writeOff('lost')
                        : null,
                  ),
                ],
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

class _BucketCard extends StatelessWidget {
  final String title;
  final double value;
  final String unit;
  final IconData icon;
  final AppStatusTone tone;

  const _BucketCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      AppStatusTone.success => (
          const Color(0xFFEAF6EF),
          SifaBrand.success,
        ),
      AppStatusTone.warning => (
          const Color(0xFFFFF4E5),
          const Color(0xFF9A5D00),
        ),
      AppStatusTone.danger => (
          const Color(0xFFFFECEC),
          const Color(0xFFA53C3C),
        ),
      _ => (
          SifaBrand.ivory,
          SifaBrand.charcoal,
        ),
    };

    return SizedBox(
      width: 165,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: palette.$1,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: palette.$2),
            const SizedBox(height: 8),
            Text(
              '${_StockMaintenanceScreenState._number(value)} $unit',
              style: TextStyle(
                color: palette.$2,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: SifaBrand.textGrey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        enabled: onTap != null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SifaBrand.gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: onTap == null
                ? SifaBrand.textGrey
                : SifaBrand.deepGold,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.chevron_right,
          color: SifaBrand.deepGold,
        ),
        onTap: onTap,
      ),
    );
  }
}
