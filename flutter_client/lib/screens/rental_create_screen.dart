import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/customer_api_repository.dart';
import '../services/rental_api_repository.dart';

class RentalCreateScreen extends StatefulWidget {
  final Customer customer;

  const RentalCreateScreen({
    super.key,
    required this.customer,
  });

  @override
  State<RentalCreateScreen> createState() => _RentalCreateScreenState();
}

class _RentalCreateScreenState extends State<RentalCreateScreen> {
  final repo = RentalApiRepository();
  final customerRepo = CustomerApiRepository();
  final uuid = const Uuid();

  DateTime date = DateTime.now();
  InvoicePreference invoicePreference = InvoicePreference.noInvoice;
  final note = TextEditingController();
  final List<_RentalLine> lines = [];
  List<Map<String, dynamic>> addresses = [];
  String? addressId;
  bool loadingAddresses = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final rows = await customerRepo.addressesOfflineFirst(
        widget.customer.id,
      );
      if (mounted) {
        setState(() {
          addresses = rows;
          loadingAddresses = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loadingAddresses = false);
    }
  }

  Future<void> _addAddress() async {
    final label = TextEditingController();
    final full = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Şantiye / Adres'),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: label,
                decoration: const InputDecoration(
                  labelText: 'Kısa ad',
                  hintText: 'Örn. Ümraniye Şantiyesi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: full,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açık adres',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (label.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (save == true) {
      final id = await customerRepo.addAddressOfflineSafe(
        customerId: widget.customer.id,
        label: label.text.trim(),
        fullAddress:
            full.text.trim().isEmpty ? null : full.text.trim(),
      );
      await _loadAddresses();
      if (mounted) setState(() => addressId = id);
    }

    label.dispose();
    full.dispose();
  }

  Future<void> _addLine() async {
    final line = await showDialog<_RentalLine>(
      context: context,
      builder: (_) => const _RentalLineDialog(),
    );
    if (line != null) setState(() => lines.add(line));
  }

  Future<void> _save() async {
    if (lines.isEmpty) return;

    setState(() => saving = true);
    try {
      final payload = {
        'customer_id': widget.customer.id,
        'address_id': addressId,
        'original_outbound_date': _date(date),
        'invoice_preference': invoicePreference ==
                InvoicePreference.invoiceRequired
            ? 'invoice_required'
            : 'no_invoice',
        'note': note.text.trim().isEmpty ? null : note.text.trim(),
        'items': lines
            .map(
              (line) => {
                'id': line.id,
                'product_id': line.product.id,
                'quantity': line.quantity,
                'first_rate_amount': line.rate,
                'rate_type': line.rateType,
              },
            )
            .toList(),
      };

      final id = await repo.createOfflineSafe(payload);
      if (mounted) Navigator.pop(context, id);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customer.name} • Yeni Kiralama'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Müşteri, şantiye ve kiralama internet yokken de oluşturulabilir.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: addressId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Şantiye / Adres',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Adres seçilmedi'),
                    ),
                    ...addresses.map(
                      (a) => DropdownMenuItem<String?>(
                        value: a['id'].toString(),
                        child: Text(a['label'].toString()),
                      ),
                    ),
                  ],
                  onChanged: loadingAddresses
                      ? null
                      : (v) => setState(() => addressId = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Yeni şantiye/adres ekle',
                onPressed: _addAddress,
                icon: const Icon(Icons.add_location_alt_outlined),
              ),
            ],
          ),
          if (loadingAddresses) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('İlk çıkış tarihi'),
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
          SegmentedButton<InvoicePreference>(
            segments: const [
              ButtonSegment(
                value: InvoicePreference.invoiceRequired,
                label: Text('Faturalı'),
              ),
              ButtonSegment(
                value: InvoicePreference.noInvoice,
                label: Text('Faturasız'),
              ),
            ],
            selected: {invoicePreference},
            onSelectionChanged: (v) {
              setState(() => invoicePreference = v.first);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kiralanan Malzemeler',
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
                child: Text('En az bir kiralık malzeme ekle.'),
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
                      '${entry.value.quantity} ${entry.value.product.unit.label}'
                      '${entry.value.rate == null ? "" : " • ${entry.value.rate} ₺"}',
                    ),
                    trailing: IconButton(
                      onPressed: () => setState(
                        () => lines.removeAt(entry.key),
                      ),
                      icon: const Icon(Icons.delete_outline),
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
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving || lines.isEmpty ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                saving ? 'Kaydediliyor…' : 'KİRALAMAYI KAYDET',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _RentalLineDialog extends StatefulWidget {
  const _RentalLineDialog();

  @override
  State<_RentalLineDialog> createState() => _RentalLineDialogState();
}

class _RentalLineDialogState extends State<_RentalLineDialog> {
  final uuid = const Uuid();
  Product? selected;
  final quantity = TextEditingController();
  final rate = TextEditingController();
  String rateType = 'per_unit_monthly';

  @override
  void dispose() {
    quantity.dispose();
    rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kiralık Malzeme'),
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
                        p.tradeMode == TradeMode.rental ||
                        p.tradeMode == TradeMode.both,
                  )
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: quantity,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Miktar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: rate,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'İlk kira fiyatı (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: rateType,
              decoration: const InputDecoration(
                labelText: 'Fiyat tipi',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'per_unit_monthly',
                  child: Text('Birim başına aylık'),
                ),
                DropdownMenuItem(
                  value: 'fixed_monthly',
                  child: Text('Sabit aylık'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => rateType = v);
              },
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
            final p = selected;
            final q = double.tryParse(
              quantity.text.replaceAll(',', '.'),
            );
            final r = rate.text.trim().isEmpty
                ? null
                : double.tryParse(rate.text.replaceAll(',', '.'));

            if (p == null || q == null || q <= 0) return;

            Navigator.pop(
              context,
              _RentalLine(
                id: uuid.v4(),
                product: p,
                quantity: q,
                rate: r,
                rateType: rateType,
              ),
            );
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}

class _RentalLine {
  final String id;
  final Product product;
  final double quantity;
  final double? rate;
  final String rateType;

  const _RentalLine({
    required this.id,
    required this.product,
    required this.quantity,
    required this.rate,
    required this.rateType,
  });
}
