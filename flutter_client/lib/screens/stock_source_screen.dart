import 'package:flutter/material.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/role_service.dart';
import '../services/stock_source_repository.dart';

class StockSourceScreen extends StatefulWidget {
  const StockSourceScreen({super.key});

  @override
  State<StockSourceScreen> createState() => _StockSourceScreenState();
}

class _StockSourceScreenState extends State<StockSourceScreen> {
  final repo = StockSourceRepository();
  final roles = RoleService();
  bool canWrite = false;

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
    if (!canWrite) return;
    final result = await showDialog<_StockEntry>(
      context: context,
      builder: (_) => const _StockEntryDialog(
        title: 'Açılış Stoğu',
        allowCost: false,
      ),
    );
    if (result == null) return;

    await repo.openingStock({
      'product_id': result.product.id,
      'quantity': result.quantity,
      'movement_date': _date(DateTime.now()),
      'note': 'İlk açılış stoğu',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Açılış stoğu kaydedildi/kuyruğa alındı.'),
        ),
      );
    }
  }

  Future<void> _purchase() async {
    if (!canWrite) return;
    final result = await showDialog<_StockEntry>(
      context: context,
      builder: (_) => const _StockEntryDialog(
        title: 'Satın Alma',
        allowCost: true,
      ),
    );
    if (result == null) return;

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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satın alma kaydedildi/kuyruğa alındı.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Stok Girişleri',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Açılış stoğu yalnız ilk başlangıçta kullanılır. '
          'Daha sonraki gerçek girişler satın alma veya sayım düzeltmesi olmalıdır.',
        ),
        const SizedBox(height: 16),
        if (!canWrite)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Bu hesap yalnız görüntüleme yetkisinde.'),
            ),
          )
        else ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text(
                'Açılış Stoğu',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Takibe ilk kez alınan malzemenin başlangıç miktarı.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _opening,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text(
                'Satın Alma Girişi',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Yeni alınan malzeme kullanılabilir stoğa eklenir.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _purchase,
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
                onChanged: (v) => setState(() => product = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Miktar',
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.allowCost) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Birim alış maliyeti (isteğe bağlı)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: supplier,
                  decoration: const InputDecoration(
                    labelText: 'Tedarikçi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: invoiceNo,
                  decoration: const InputDecoration(
                    labelText: 'Fatura no',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  border: OutlineInputBorder(),
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
            final p = product;
            final quantity =
                double.tryParse(qty.text.replaceAll(',', '.'));
            final unitCost = cost.text.trim().isEmpty
                ? null
                : double.tryParse(cost.text.replaceAll(',', '.'));

            if (p == null || quantity == null || quantity < 0) return;

            Navigator.pop(
              context,
              _StockEntry(
                product: p,
                quantity: quantity,
                unitCost: unitCost,
                supplierName:
                    supplier.text.trim().isEmpty ? null : supplier.text.trim(),
                invoiceNo:
                    invoiceNo.text.trim().isEmpty ? null : invoiceNo.text.trim(),
                note: note.text.trim().isEmpty ? null : note.text.trim(),
              ),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
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
