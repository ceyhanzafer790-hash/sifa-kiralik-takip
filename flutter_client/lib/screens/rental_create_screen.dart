import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/seed_products.dart';
import '../models/models.dart';
import '../services/customer_api_repository.dart';
import '../services/rental_api_repository.dart';
import '../widgets/sifa_brand.dart';

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
      if (!mounted) return;
      setState(() {
        addresses = rows;
        loadingAddresses = false;
      });
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
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: full,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Açık adres',
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
        fullAddress: full.text.trim().isEmpty ? null : full.text.trim(),
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

  Future<void> _editLine(int index) async {
    final updated = await showDialog<_RentalLine>(
      context: context,
      builder: (_) => _RentalLineDialog(initial: lines[index]),
    );
    if (updated != null && mounted) {
      setState(() => lines[index] = updated);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (picked != null && mounted) {
      setState(() => date = picked);
    }
  }

  Future<void> _save() async {
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce en az bir kiralık malzeme ekle.'),
        ),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final payload = {
        'customer_id': widget.customer.id,
        'address_id': addressId,
        'original_outbound_date': _date(date),
        'invoice_preference':
            invoicePreference == InvoicePreference.invoiceRequired
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
      if (!mounted) return;
      Navigator.pop(context, id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kiralama kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? selectedAddress;
    for (final address in addresses) {
      if (address['id'].toString() == addressId) {
        selectedAddress = address;
        break;
      }
    }
    final fullAddress =
        selectedAddress?['full_address']?.toString().trim();
    final pricedCount = lines.where((line) => line.rate != null).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yeni Kiralama',
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: SifaBrand.charcoal,
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: SifaBrand.gold.withOpacity(0.45),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const SifaBuildingMark(size: 31),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Yeni kiralık çıkış hazırlanıyor',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.local_shipping_outlined,
                        color: SifaBrand.gold,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _StepPill(
                          number: '1',
                          label: 'Müşteri',
                          done: true,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _StepPill(
                          number: '2',
                          label: 'Şantiye',
                          active: lines.isEmpty,
                          done: lines.isNotEmpty,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: _StepPill(
                          number: '3',
                          label: 'Malzeme',
                          active: lines.isNotEmpty,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Şantiye & Çıkış',
            icon: Icons.location_on_outlined,
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: addressId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Şantiye / Adres',
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
                if (loadingAddresses) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (fullAddress != null && fullAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      fullAddress,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SifaBrand.textGrey,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: SifaBrand.ivory,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SifaBrand.softGrey),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: SifaBrand.deepGold,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'İlk çıkış tarihi',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          _displayDate(date),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<InvoicePreference>(
                  segments: const [
                    ButtonSegment(
                      value: InvoicePreference.invoiceRequired,
                      icon: Icon(Icons.receipt_long_outlined),
                      label: Text('Faturalı'),
                    ),
                    ButtonSegment(
                      value: InvoicePreference.noInvoice,
                      icon: Icon(Icons.money_off_outlined),
                      label: Text('Faturasız'),
                    ),
                  ],
                  selected: {invoicePreference},
                  onSelectionChanged: (v) {
                    setState(() => invoicePreference = v.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
              if (lines.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: SifaBrand.goldBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${lines.length} kalem',
                    style: const TextStyle(
                      color: SifaBrand.deepGold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (lines.isEmpty)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _addLine,
                child: const Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_box_outlined,
                        size: 34,
                        color: SifaBrand.deepGold,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Henüz malzeme eklenmedi',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Miktar ve ilk kira fiyatını eklemek için dokun.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...lines.asMap().entries.map(
              (entry) => _RentalLineCard(
                line: entry.value,
                onEdit: () => _editLine(entry.key),
                onDelete: () => setState(
                  () => lines.removeAt(entry.key),
                ),
              ),
            ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Not',
            icon: Icons.notes_outlined,
            child: TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'İsteğe bağlı açıklama ekle',
              ),
            ),
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kaydetmeden Önce',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 11),
                    _SummaryRow(
                      icon: Icons.business_outlined,
                      label: 'Müşteri',
                      value: widget.customer.name,
                    ),
                    _SummaryRow(
                      icon: Icons.location_on_outlined,
                      label: 'Şantiye',
                      value: selectedAddress?['label']?.toString() ??
                          'Adres seçilmedi',
                    ),
                    _SummaryRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Malzeme',
                      value:
                          '${lines.length} kalem • $pricedCount fiyatlı',
                    ),
                    _SummaryRow(
                      icon: Icons.calendar_month_outlined,
                      label: 'İlk çıkış',
                      value: _displayDate(date),
                    ),
                    _SummaryRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Fatura',
                      value:
                          invoicePreference == InvoicePreference.invoiceRequired
                              ? 'Faturalı'
                              : 'Faturasız',
                      last: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving || lines.isEmpty ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.local_shipping_outlined),
            label: Text(
              saving ? 'Kaydediliyor…' : 'Kiralama ve Sevkiyatı Kaydet',
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

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SifaBrand.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: SifaBrand.deepGold,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String number;
  final String label;
  final bool active;
  final bool done;

  const _StepPill({
    required this.number,
    required this.label,
    this.active = false,
    this.done = false,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = active || done;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted ? SifaBrand.goldBg : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: highlighted
              ? SifaBrand.gold.withOpacity(0.35)
              : SifaBrand.softGrey,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: done
                  ? SifaBrand.charcoal
                  : active
                      ? SifaBrand.gold
                      : SifaBrand.softGrey,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              done ? Icons.check : Icons.circle,
              size: done ? 13 : 7,
              color: done
                  ? SifaBrand.gold
                  : active
                      ? SifaBrand.charcoal
                      : SifaBrand.textGrey,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    highlighted ? SifaBrand.charcoal : SifaBrand.textGrey,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RentalLineCard extends StatelessWidget {
  final _RentalLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RentalLineCard({
    required this.line,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SifaBrand.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: SifaBrand.deepGold,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_clean(line.quantity)} ${line.product.unit.label}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line.rate == null
                            ? 'Fiyat girilmedi'
                            : '${_clean(line.rate!)} ₺ • '
                                '${line.rateType == 'fixed_monthly' ? 'Sabit aylık' : 'Birim başına aylık'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: line.rate == null
                                  ? Theme.of(context).colorScheme.error
                                  : SifaBrand.textGrey,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Düzenle',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: SifaBrand.deepGold,
                  ),
                ),
                IconButton(
                  tooltip: 'Sil',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _clean(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      margin: EdgeInsets.only(bottom: last ? 0 : 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: SifaBrand.deepGold),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _RentalLineDialog extends StatefulWidget {
  final _RentalLine? initial;

  const _RentalLineDialog({this.initial});

  @override
  State<_RentalLineDialog> createState() => _RentalLineDialogState();
}

class _RentalLineDialogState extends State<_RentalLineDialog> {
  final uuid = const Uuid();
  Product? selected;
  late final TextEditingController quantity;
  late final TextEditingController rate;
  String rateType = 'per_unit_monthly';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    selected = initial?.product;
    quantity = TextEditingController(
      text: initial == null ? '' : _clean(initial.quantity),
    );
    rate = TextEditingController(
      text: initial?.rate == null ? '' : _clean(initial!.rate!),
    );
    rateType = initial?.rateType ?? 'per_unit_monthly';
  }

  @override
  void dispose() {
    quantity.dispose();
    rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Kiralık Malzeme Ekle' : 'Malzemeyi Düzenle',
      ),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                value: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Malzeme',
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
                decoration: InputDecoration(
                  labelText: 'Miktar',
                  suffixText: selected?.unit.label,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rate,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'İlk kira fiyatı',
                  hintText: 'İsteğe bağlı',
                  suffixText: '₺',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: rateType,
                decoration: const InputDecoration(
                  labelText: 'Fiyat tipi',
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
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: SifaBrand.goldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.history,
                      size: 18,
                      color: SifaBrand.deepGold,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu ilk fiyat daha sonra değiştirilebilir. Eski fiyatlar tarihçede korunur.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
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
            final p = selected;
            final q = double.tryParse(
              quantity.text.replaceAll(',', '.'),
            );
            final r = rate.text.trim().isEmpty
                ? null
                : double.tryParse(rate.text.replaceAll(',', '.'));

            if (p == null || q == null || q <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Malzeme ve geçerli bir miktar gir.'),
                ),
              );
              return;
            }

            Navigator.pop(
              context,
              _RentalLine(
                id: widget.initial?.id ?? uuid.v4(),
                product: p,
                quantity: q,
                rate: r,
                rateType: rateType,
              ),
            );
          },
          child: Text(widget.initial == null ? 'Ekle' : 'Kaydet'),
        ),
      ],
    );
  }

  static String _clean(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
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
