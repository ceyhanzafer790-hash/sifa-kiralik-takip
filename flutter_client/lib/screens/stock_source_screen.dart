import 'package:flutter/material.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/role_service.dart';
import '../services/stock_source_repository.dart';
import '../widgets/sifa_brand.dart';

class StockSourceScreen extends StatefulWidget {
  const StockSourceScreen({super.key});

  @override
  State<StockSourceScreen> createState() => _StockSourceScreenState();
}

class _StockSourceScreenState extends State<StockSourceScreen> {
  final repo = StockSourceRepository();
  final roles = RoleService();
  bool canWrite = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final value = await roles.canWrite();
    if (mounted) setState(() => canWrite = value);
  }

  Future<void> _opening() async {
    if (!canWrite || saving) return;

    final result = await showDialog<_StockEntry>(
      context: context,
      builder: (_) => const _StockEntryDialog(
        title: 'Açılış Stoğu',
        allowCost: false,
      ),
    );
    if (result == null) return;

    await _run(() async {
      await repo.openingStock({
        'product_id': result.product.id,
        'quantity': result.quantity,
        'movement_date': _date(DateTime.now()),
        'note': result.note ?? 'İlk açılış stoğu',
      });
      _message('Açılış stoğu kaydedildi veya senkron kuyruğuna alındı.');
    });
  }

  Future<void> _purchase() async {
    if (!canWrite || saving) return;

    final result = await showDialog<_StockEntry>(
      context: context,
      builder: (_) => const _StockEntryDialog(
        title: 'Satın Alma Girişi',
        allowCost: true,
      ),
    );
    if (result == null) return;

    await _run(() async {
      await repo.purchase({
        'supplier_name': result.supplierName,
        'purchase_date': _date(DateTime.now()),
        'invoice_no': result.invoiceNo,
        'note': result.note,
        'items': [
          {
            'product_id': result.product.id,
            'quantity': result.quantity,
            'unit_cost': result.unitCost,
          }
        ],
      });
      _message('Satın alma kaydedildi veya senkron kuyruğuna alındı.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
    } catch (e) {
      _message('Stok girişi kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Stok Girişi',
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
                        Icons.add_box_outlined,
                        color: SifaBrand.gold,
                        size: 28,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Depoya Malzeme Ekle',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Başlangıç stoğu ile gerçek satın almayı ayrı kaydet.',
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
                          'Bağlantı yoksa giriş cihazda saklanır ve sonra senkronlanır.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!canWrite)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Bu hesap yalnız görüntüleme yetkisine sahip.',
                ),
              ),
            )
          else ...[
            _SourceCard(
              icon: Icons.flag_outlined,
              title: 'Açılış Stoğu',
              subtitle:
                  'Sisteme ilk kez alınan mevcut malzemenin başlangıç miktarı.',
              badge: 'Sadece başlangıç',
              onTap: saving ? null : _opening,
            ),
            const SizedBox(height: 10),
            _SourceCard(
              icon: Icons.shopping_cart_outlined,
              title: 'Satın Alma Girişi',
              subtitle:
                  'Yeni alınan malzemeyi miktar, tedarikçi ve maliyet bilgisiyle ekle.',
              badge: 'Normal giriş',
              onTap: saving ? null : _purchase,
            ),
          ],
          if (saving) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SifaBrand.ivory,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: SifaBrand.softGrey),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: SifaBrand.deepGold,
                  size: 19,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fiziksel stok farkını düzeltmek için Açılış Stoğu kullanma. '
                    'Bunun yerine Depo Sayımı ekranından gerçek sayımı gir.',
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
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback? onTap;

  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: SifaBrand.gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: onTap == null
                      ? SifaBrand.textGrey
                      : SifaBrand.deepGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: SifaBrand.goldBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: SifaBrand.deepGold,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: SifaBrand.textGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: SifaBrand.deepGold,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockEntryDialog extends StatefulWidget {
  final String title;
  final bool allowCost;

  const _StockEntryDialog({
    required this.title,
    required this.allowCost,
  });

  @override
  State<_StockEntryDialog> createState() => _StockEntryDialogState();
}

class _StockEntryDialogState extends State<_StockEntryDialog> {
  Product? product;
  final qty = TextEditingController();
  final cost = TextEditingController();
  final supplier = TextEditingController();
  final invoiceNo = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() {
    qty.dispose();
    cost.dispose();
    supplier.dispose();
    invoiceNo.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsedQty =
        double.tryParse(qty.text.replaceAll(',', '.')) ?? 0;
    final parsedCost =
        double.tryParse(cost.text.replaceAll(',', '.')) ?? 0;
    final totalCost = parsedQty * parsedCost;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: product,
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
                onChanged: (value) => setState(() => product = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Miktar',
                  suffixText: product?.unit.label,
                  prefixIcon: const Icon(Icons.numbers_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.allowCost) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Birim alış maliyeti',
                    hintText: 'İsteğe bağlı',
                    prefixIcon: Icon(Icons.currency_lira),
                    suffixText: '₺',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (parsedQty > 0 && parsedCost > 0) ...[
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Tahmini toplam: ${_money(totalCost)} ₺',
                      style: const TextStyle(
                        color: SifaBrand.deepGold,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: supplier,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Tedarikçi',
                    hintText: 'İsteğe bağlı',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: invoiceNo,
                  decoration: const InputDecoration(
                    labelText: 'Fatura no',
                    hintText: 'İsteğe bağlı',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  hintText: 'İsteğe bağlı',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final selectedProduct = product;
            final quantity =
                double.tryParse(qty.text.replaceAll(',', '.'));
            final unitCost = cost.text.trim().isEmpty
                ? null
                : double.tryParse(cost.text.replaceAll(',', '.'));

            if (selectedProduct == null ||
                quantity == null ||
                quantity <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Malzeme ve geçerli bir miktar gir.'),
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              _StockEntry(
                product: selectedProduct,
                quantity: quantity,
                unitCost: unitCost,
                supplierName: supplier.text.trim().isEmpty
                    ? null
                    : supplier.text.trim(),
                invoiceNo: invoiceNo.text.trim().isEmpty
                    ? null
                    : invoiceNo.text.trim(),
                note: note.text.trim().isEmpty
                    ? null
                    : note.text.trim(),
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final chars = parts[0].split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }

    final whole = groups.reversed.join('.');
    return parts[1] == '00' ? whole : '$whole,${parts[1]}';
  }
}

class _StockEntry {
  final Product product;
  final double quantity;
  final double? unitCost;
  final String? supplierName;
  final String? invoiceNo;
  final String? note;

  const _StockEntry({
    required this.product,
    required this.quantity,
    required this.unitCost,
    required this.supplierName,
    required this.invoiceNo,
    required this.note,
  });
}
