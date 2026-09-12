import 'package:flutter/material.dart';

import '../services/offline_document_queue.dart';
import '../services/rental_api_repository.dart';
import '../services/rental_date_service.dart';
import '../services/role_service.dart';

class RentalTrackingDetailScreen extends StatefulWidget {
  final String recordId;

  const RentalTrackingDetailScreen({
    super.key,
    required this.recordId,
  });

  @override
  State<RentalTrackingDetailScreen> createState() =>
      _RentalTrackingDetailScreenState();
}

class _RentalTrackingDetailScreenState
    extends State<RentalTrackingDetailScreen> {
  final repo = RentalApiRepository();
  final roles = RoleService();
  final documentQueue = OfflineDocumentQueue();

  Map<String, dynamic>? detail;
  bool loading = true;
  bool canWrite = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _load();
  }

  Future<void> _loadRole() async {
    final value = await roles.canWrite();
    if (mounted) setState(() => canWrite = value);
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data =
          await repo.rentalDetailOfflineFirst(widget.recordId);
      if (mounted) setState(() => detail = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _addReturn(Map<String, dynamic> item) async {
    if (!canWrite) return;

    final initial =
        (item['initial_quantity'] as num?)?.toDouble() ?? 0;
    final returned =
        (item['returned_quantity'] as num?)?.toDouble() ?? 0;
    final remaining = initial - returned;

    final qty = TextEditingController();
    DateTime date = DateTime.now();
    String condition = 'usable';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${item['product_name']} • İade'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kirada kalan: ${_n(remaining)} ${_unit(item['unit'])}'),
                const SizedBox(height: 10),
                TextField(
                  controller: qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'İade miktarı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: condition,
                  decoration: const InputDecoration(
                    labelText: 'Dönüş durumu',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'usable',
                      child: Text('Kullanılabilir'),
                    ),
                    DropdownMenuItem(
                      value: 'repair',
                      child: Text('Tamirlik'),
                    ),
                    DropdownMenuItem(
                      value: 'scrap',
                      child: Text('Hurda'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => condition = v);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('İade tarihi'),
                  subtitle: Text(trDate(date)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: date,
                    );
                    if (picked != null) {
                      setDialogState(() => date = picked);
                    }
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
                final q = double.tryParse(
                  qty.text.replaceAll(',', '.'),
                );
                if (q == null || q <= 0 || q > remaining) return;
                Navigator.pop(
                  context,
                  {
                    'quantity': q,
                    'date': date,
                    'condition': condition,
                  },
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    qty.dispose();
    if (result == null) return;

    await repo.addReturnOfflineSafe(
      rentalId: widget.recordId,
      rentalItemId: item['id'].toString(),
      productId: item['product_id'].toString(),
      quantity: (result['quantity'] as num).toDouble(),
      movementDate: result['date'] as DateTime,
      returnCondition: result['condition'].toString(),
    );

    await _load();
  }

  Future<void> _addRate(Map<String, dynamic> item) async {
    if (!canWrite) return;

    final amount = TextEditingController();
    DateTime effective = DateTime.now();
    String type = 'per_unit_monthly';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${item['product_name']} • Fiyat'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Yeni kira fiyatı (₺)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
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
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Geçerlilik başlangıcı'),
                  subtitle: Text(trDate(effective)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDate: effective,
                    );
                    if (picked != null) {
                      setDialogState(() => effective = picked);
                    }
                  },
                ),
                const Text(
                  'Eski fiyat silinmez. Yeni fiyat bu tarihten itibaren geçerlidir.',
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
                final a = double.tryParse(
                  amount.text.replaceAll(',', '.'),
                );
                if (a == null || a < 0) return;
                Navigator.pop(
                  context,
                  {
                    'amount': a,
                    'effective': effective,
                    'type': type,
                  },
                );
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    amount.dispose();
    if (result == null) return;

    await repo.addRateOfflineSafe(
      rentalId: widget.recordId,
      rentalItemId: item['id'].toString(),
      productId: item['product_id'].toString(),
      effectiveFrom: result['effective'] as DateTime,
      amount: (result['amount'] as num).toDouble(),
      rateType: result['type'].toString(),
    );

    await _load();
  }

  Future<void> _toggleInvoice(String current) async {
    if (!canWrite) return;
    final next =
        current == 'invoice_required' ? 'no_invoice' : 'invoice_required';

    await repo.setInvoicePreferenceOfflineSafe(
      rentalId: widget.recordId,
      invoicePreference: next,
    );

    await _load();
  }

  Future<void> _queueDocument(
    String type, {
    String? movementId,
  }) async {
    if (!canWrite) return;

    final id = await documentQueue.pickAndQueue(
      rentalRecordId: widget.recordId,
      rentalMovementId: movementId,
      documentType: type,
    );

    if (id != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belge güvenli kuyruğa alındı. İnternet gelince otomatik yüklenecek.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && detail == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kiralama Takibi')),
        body: Center(child: Text(error ?? 'Kayıt bulunamadı.')),
      );
    }

    final rental =
        Map<String, dynamic>.from(detail!['rental'] as Map);
    final items = ((detail!['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final movements = ((detail!['movements'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final rates = ((detail!['rates'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final docs = ((detail!['documents'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final original = DateTime.parse(
      rental['original_outbound_date'].toString(),
    );
    final nextRenewal = nextMonthlyRentalDate(original, DateTime.now());
    final invoice = rental['invoice_preference']?.toString() ?? 'no_invoice';
    final pending = rental['pending_sync'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiralama Takibi Detayı'),
        actions: [
          if (pending)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Chip(
                avatar: Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text('Senkron bekliyor'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rental['customer_name']?.toString() ?? 'Müşteri',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (rental['address_label'] != null)
                      Text(rental['address_label'].toString()),
                    if (rental['full_address'] != null)
                      Text(rental['full_address'].toString()),
                    const Divider(height: 24),
                    Text('İlk çıkış: ${trDate(original)}'),
                    Text(
                      'Sonraki kira: ${trDate(nextRenewal)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    ActionChip(
                      avatar: Icon(
                        invoice == 'invoice_required'
                            ? Icons.receipt_long_outlined
                            : Icons.money_off_outlined,
                      ),
                      label: Text(
                        invoice == 'invoice_required'
                            ? 'Faturalı'
                            : 'Faturasız',
                      ),
                      onPressed: canWrite
                          ? () => _toggleInvoice(invoice)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _title(context, 'Kiradaki Malzemeler'),
            const SizedBox(height: 8),
            ...items.map((item) {
              final initial =
                  (item['initial_quantity'] as num?)?.toDouble() ?? 0;
              final returned =
                  (item['returned_quantity'] as num?)?.toDouble() ?? 0;
              final remaining = initial - returned;

              final itemRates = rates
                  .where(
                    (r) =>
                        r['rental_item_id'].toString() ==
                        item['id'].toString(),
                  )
                  .toList()
                ..sort(
                  (a, b) => DateTime.parse(
                    b['effective_from'].toString(),
                  ).compareTo(
                    DateTime.parse(a['effective_from'].toString()),
                  ),
                );

              final currentRate =
                  itemRates.isEmpty ? null : itemRates.first;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product_name'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Gönderilen: ${_n(initial)} ${_unit(item['unit'])}',
                        ),
                        Text(
                          'İade: ${_n(returned)} ${_unit(item['unit'])}',
                        ),
                        Text(
                          'Kirada kalan: ${_n(remaining)} ${_unit(item['unit'])}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          currentRate == null
                              ? 'Fiyat girilmedi'
                              : 'Güncel fiyat: ${currentRate['amount']} ₺ • '
                                  '${currentRate['rate_type'] == 'fixed_monthly' ? "Sabit aylık" : "Birim başına aylık"}',
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: canWrite && remaining > 0
                                  ? () => _addReturn(item)
                                  : null,
                              icon: const Icon(Icons.keyboard_return),
                              label: const Text('İade Ekle'),
                            ),
                            OutlinedButton.icon(
                              onPressed: canWrite
                                  ? () => _addRate(item)
                                  : null,
                              icon: const Icon(Icons.price_change_outlined),
                              label: const Text('Fiyat'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            _title(context, 'Belgeler'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: canWrite
                              ? () => _queueDocument('contract')
                              : null,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Kira Sözleşmesi'),
                        ),
                        OutlinedButton.icon(
                          onPressed: canWrite
                              ? () => _queueDocument('outbound_delivery')
                              : null,
                          icon: const Icon(Icons.north_east),
                          label: const Text('Giden Belgesi'),
                        ),
                        OutlinedButton.icon(
                          onPressed: canWrite
                              ? () => _queueDocument('inbound_delivery')
                              : null,
                          icon: const Icon(Icons.south_west),
                          label: const Text('Gelen Belgesi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (docs.isEmpty)
                      const Text('Sunucudan senkronize edilmiş belge yok.')
                    else
                      ...docs.map(
                        (d) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file),
                          title: Text(
                            d['original_file_name'].toString(),
                          ),
                          subtitle: Text(
                            d['document_type'].toString(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _title(context, 'Hareket Geçmişi'),
            const SizedBox(height: 8),
            ...movements.map(
              (m) {
                final item = items.firstWhere(
                  (i) =>
                      i['id'].toString() ==
                      m['rental_item_id'].toString(),
                  orElse: () => {
                    'product_name': 'Malzeme',
                    'unit': 'piece',
                  },
                );

                final inbound =
                    m['movement_type'] == 'inbound_return';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        inbound ? Icons.south_west : Icons.north_east,
                      ),
                      title: Text(
                        '${inbound ? "Gelen" : "Giden"} '
                        '${_n((m['quantity'] as num?)?.toDouble() ?? 0)} '
                        '${_unit(item['unit'])} '
                        '${item['product_name']}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${trDate(DateTime.parse(m['movement_date'].toString()))}'
                        '${m['return_condition'] == null ? "" : " • ${_condition(m['return_condition'].toString())}"}'
                        '${m['pending_sync'] == true ? " • Senkron bekliyor" : ""}',
                      ),
                      trailing: inbound && canWrite
                          ? IconButton(
                              tooltip: 'Bu iadeye belge ekle',
                              onPressed: () => _queueDocument(
                                'inbound_delivery',
                                movementId: m['id'].toString(),
                              ),
                              icon: const Icon(Icons.attach_file),
                            )
                          : !inbound && canWrite
                              ? IconButton(
                                  tooltip: 'Bu çıkışa belge ekle',
                                  onPressed: () => _queueDocument(
                                    'outbound_delivery',
                                    movementId: m['id'].toString(),
                                  ),
                                  icon: const Icon(Icons.attach_file),
                                )
                              : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _title(context, 'Fiyat Geçmişi'),
            const SizedBox(height: 8),
            if (rates.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Henüz fiyat geçmişi yok.'),
                ),
              )
            else
              ...rates.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.price_change_outlined),
                      title: Text(
                        '${r['product_name']} • ${r['amount']} ₺',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${trDate(DateTime.parse(r['effective_from'].toString()))} tarihinden itibaren'
                        '${r['pending_sync'] == true ? " • Senkron bekliyor" : ""}',
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _title(BuildContext context, String title) => Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      );

  String _n(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  String _unit(dynamic unit) => switch (unit?.toString()) {
        'sheet' => 'Levha',
        'meter' => 'Metre',
        'squareMeter' || 'square_meter' => 'm²',
        'cubicMeter' || 'cubic_meter' => 'm³',
        'kilogram' => 'kg',
        'liter' => 'Litre',
        'set' => 'Takım',
        _ => 'Adet',
      };

  String _condition(String value) => switch (value) {
        'repair' => 'Tamirlik',
        'scrap' => 'Hurda',
        _ => 'Kullanılabilir',
      };
}
