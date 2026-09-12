import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/api_config.dart';
import '../services/offline_sync_service.dart';
import '../services/role_service.dart';
import '../services/sales_api_repository.dart';

class SalesScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const SalesScreen({
    super.key,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final repo = SalesApiRepository();
  final queue = OfflineSyncService();
  final uuid = const Uuid();
  final roleService = RoleService();

  List<Map<String, dynamic>> sales = [];
  bool canWrite = false;
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRole();
    if (ApiConfig.configured) _load();
  }

  Future<void> _loadRole() async {
    final allowed = await roleService.canWrite();
    if (mounted) setState(() => canWrite = allowed);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await repo.forCustomer(widget.customerId);
      if (mounted) setState(() => sales = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _newSale() async {
    if (!canWrite) return;

    final draft = await Navigator.of(context).push<_SaleDraft>(
      MaterialPageRoute(
        builder: (_) => _NewSaleScreen(
          customerName: widget.customerName,
        ),
      ),
    );
    if (draft == null) return;

    final saleId = uuid.v4();
    final operationId = uuid.v4();
    final payload = {
      'id': saleId,
      'customer_id': widget.customerId,
      'sale_date': _date(draft.date),
      'note': draft.note,
      'items': draft.lines
          .map(
            (line) => {
              'product_id': line.product.id,
              'quantity': line.quantity,
              'unit_price': line.unitPrice,
            },
          )
          .toList(),
    };

    if (ApiConfig.configured) {
      try {
        await repo.create({
          ...payload,
          'client_operation_id': operationId,
        });
        await _load();
        return;
      } catch (_) {
        // Ağ problemi varsa aşağıdaki kalıcı kuyruğa girer.
      }
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createSale,
      payload,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Satış telefona kaydedildi. Bağlantı gelince merkeze gönderilecek.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.customerName} • Satılanlar')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _newSale,
              icon: const Icon(Icons.add),
              label: const Text('Satış Ekle'),
            )
          : null,
      body: !ApiConfig.configured
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Sunucu kurulmadan da yeni satış telefonda offline kuyruğa alınabilir. '
                      'Gerçek satış geçmişi merkez bağlandıktan sonra burada görünür.',
                    ),
                  ),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (loading) const LinearProgressIndicator(),
                  if (error != null) Text(error!),
                  if (!loading && sales.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Henüz satış kaydı yok.'),
                      ),
                    ),
                  ...sales.map(
                    (sale) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.sell_outlined),
                          title: Text(
                            '${sale['total_amount'] ?? 0} ₺',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${sale['sale_date']}'
                            '${sale['note'] == null ? "" : " • ${sale['note']}"}',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _NewSaleScreen extends StatefulWidget {
  final String customerName;

  const _NewSaleScreen({
    required this.customerName,
  });

  @override
  State<_NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<_NewSaleScreen> {
  DateTime date = DateTime.now();
  final note = TextEditingController();
  final List<_SaleLine> lines = [];

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  double get total => lines.fold(
        0,
        (sum, line) => sum + line.quantity * line.unitPrice,
      );

  Future<void> _addLine() async {
    final result = await showDialog<_SaleLine>(
      context: context,
      builder: (_) => const _SaleLineDialog(),
    );
    if (result != null) setState(() => lines.add(result));
  }

  void _save() {
    if (lines.isEmpty) return;
    Navigator.pop(
      context,
      _SaleDraft(
        date: date,
        note: note.text.trim().isEmpty ? null : note.text.trim(),
        lines: lines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.customerName} • Yeni Satış')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Satış tarihi'),
            subtitle: Text(
              '${date.day.toString().padLeft(2, '0')}.'
              '${date.month.toString().padLeft(2, '0')}.${date.year}',
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDate: date,
              );
              if (picked != null) setState(() => date = picked);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Satış Kalemleri',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Malzeme'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Satılacak malzemeyi ekle.'),
              ),
            )
          else
            ...lines.asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    title: Text(entry.value.product.name),
                    subtitle: Text(
                      '${entry.value.quantity} ${entry.value.product.unit.label} × '
                      '${entry.value.unitPrice.toStringAsFixed(2)} ₺',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(entry.value.quantity * entry.value.unitPrice).toStringAsFixed(2)} ₺',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => lines.removeAt(entry.key),
                          ),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Not',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Toplam: ${total.toStringAsFixed(2)} ₺',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: lines.isEmpty ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Text('SATIŞI KAYDET'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleLineDialog extends StatefulWidget {
  const _SaleLineDialog();

  @override
  State<_SaleLineDialog> createState() => _SaleLineDialogState();
}

class _SaleLineDialogState extends State<_SaleLineDialog> {
  Product? selected;
  final qty = TextEditingController();
  final price = TextEditingController();

  @override
  void dispose() {
    qty.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Satış Kalemi'),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Product>(
              value: selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Malzeme',
                border: OutlineInputBorder(),
              ),
              items: products
                  .where(
                    (p) =>
                        p.tradeMode == TradeMode.sale ||
                        p.tradeMode == TradeMode.both,
                  )
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => selected = value),
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
            const SizedBox(height: 10),
            TextField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Birim satış fiyatı (₺)',
                border: OutlineInputBorder(),
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
            final product = selected;
            final quantity =
                double.tryParse(qty.text.replaceAll(',', '.'));
            final unitPrice =
                double.tryParse(price.text.replaceAll(',', '.'));

            if (product == null ||
                quantity == null ||
                quantity <= 0 ||
                unitPrice == null ||
                unitPrice < 0) {
              return;
            }

            Navigator.pop(
              context,
              _SaleLine(
                product: product,
                quantity: quantity,
                unitPrice: unitPrice,
              ),
            );
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

class _SaleLine {
  final Product product;
  final double quantity;
  final double unitPrice;

  const _SaleLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });
}

class _SaleDraft {
  final DateTime date;
  final String? note;
  final List<_SaleLine> lines;

  const _SaleDraft({
    required this.date,
    required this.note,
    required this.lines,
  });
}
