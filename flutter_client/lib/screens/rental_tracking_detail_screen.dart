import 'package:flutter/material.dart';

import '../services/offline_document_queue.dart';
import '../services/rental_account_summary_service.dart';
import '../services/rental_api_repository.dart';
import '../services/rental_date_service.dart';
import '../services/role_service.dart';
import '../widgets/status_pill.dart';
import '../widgets/sifa_brand.dart';
import 'billing_period_screen.dart';

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
  final summaryService = const RentalAccountSummaryService();

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
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final data = await repo.rentalDetailOfflineFirst(widget.recordId);
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
          title: Text('${item['product_name']} • Malzeme Geri Al'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Müşteride kalan: ${_n(remaining)} ${_unit(item['unit'])}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Gelen miktar',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: condition,
                  decoration: const InputDecoration(
                    labelText: 'Dönüş durumu',
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
                  title: const Text('Geliş tarihi'),
                  subtitle: Text(trDate(date)),
                  trailing: const Icon(Icons.calendar_month_outlined),
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
                final q = double.tryParse(qty.text.replaceAll(',', '.'));
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
    _success('Malzeme gelişi kaydedildi.');
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
          title: Text('${item['product_name']} • Yeni Fiyat'),
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
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
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
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Geçerlilik başlangıcı'),
                  subtitle: Text(trDate(effective)),
                  trailing: const Icon(Icons.calendar_month_outlined),
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
                  'Eski fiyat silinmez. Fiyat geçmişinde saklanır.',
                  style: TextStyle(fontSize: 12),
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
    _success('Yeni fiyat kaydedildi. Eski fiyat geçmişte korundu.');
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

    if (id != null) {
      await _load();
      _success('Belge eklendi. İnternet yoksa otomatik senkron bekleyecek.');
    }
  }

  Future<void> _shareWhatsApp() async {
    final current = detail;
    if (current == null) return;

    try {
      final opened = await summaryService.shareWhatsApp(current);
      if (!opened && mounted) {
        _error('WhatsApp açılamadı.');
      }
    } catch (e) {
      _error('WhatsApp özeti hazırlanamadı: $e');
    }
  }

  Future<void> _sharePdf() async {
    final current = detail;
    if (current == null) return;

    try {
      await summaryService.sharePdf(context, current);
    } catch (e) {
      _error('PDF hesap özeti hazırlanamadı: $e');
    }
  }

  Future<void> _openBilling(DateTime renewalDate) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillingPeriodScreen(
          rentalId: widget.recordId,
          renewalDate: renewalDate,
        ),
      ),
    );
    await _load();
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
        appBar: AppBar(title: const Text('Kiralama Detayı')),
        body: Center(child: Text(error ?? 'Kayıt bulunamadı.')),
      );
    }

    final rental =
        Map<String, dynamic>.from(detail!['rental'] as Map);
    final items = _maps(detail!['items']);
    final movements = _maps(detail!['movements'])
      ..sort(
        (a, b) => DateTime.parse(b['movement_date'].toString())
            .compareTo(DateTime.parse(a['movement_date'].toString())),
      );
    final rates = _maps(detail!['rates'])
      ..sort(
        (a, b) => DateTime.parse(b['effective_from'].toString())
            .compareTo(DateTime.parse(a['effective_from'].toString())),
      );
    final docs = _maps(detail!['documents']);
    final billing = _maps(detail!['billing_periods'])
      ..sort(
        (a, b) => DateTime.parse(b['renewal_date'].toString())
            .compareTo(DateTime.parse(a['renewal_date'].toString())),
      );

    final original =
        DateTime.parse(rental['original_outbound_date'].toString());
    final nextRenewal = nextMonthlyRentalDate(original, DateTime.now());
    final invoice =
        rental['invoice_preference']?.toString() ?? 'no_invoice';
    final pending = rental['pending_sync'] == true;

    final totals = _materialTotals(items);
    final accountTotals = summaryService.billingTotals(billing);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Kiralama Detayı',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            if (pending)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Center(
                  child: StatusPill(
                    label: 'Senkron bekliyor',
                    tone: AppStatusTone.info,
                    icon: Icons.cloud_upload_outlined,
                    compact: true,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _RentalHero(
                customerName:
                    rental['customer_name']?.toString() ?? 'Müşteri',
                addressLabel: rental['address_label']?.toString(),
                original: original,
                nextRenewal: nextRenewal,
                invoice: invoice,
                totals: totals,
                onToggleInvoice:
                    canWrite ? () => _toggleInvoice(invoice) : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _shareWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('WhatsApp Özeti'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sharePdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF Özeti'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Genel Bakış'),
                Tab(text: 'Hareketler'),
                Tab(text: 'Fiyatlar'),
                Tab(text: 'Ödemeler'),
                Tab(text: 'Belgeler'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _overviewTab(items, rates, accountTotals),
                  _movementsTab(movements, items),
                  _ratesTab(rates),
                  _paymentsTab(billing, nextRenewal, accountTotals),
                  _documentsTab(docs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewTab(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> rates,
    AccountTotals accountTotals,
  ) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kiradaki Malzemeler',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              StatusPill(
                label: '${items.length} kalem',
                tone: AppStatusTone.neutral,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const _EmptyCard(
              icon: Icons.inventory_2_outlined,
              title: 'Malzeme bulunmuyor',
              subtitle: 'Bu kiralama için kayıtlı malzeme yok.',
            )
          else
            ...items.map((item) {
              final initial =
                  (item['initial_quantity'] as num?)?.toDouble() ?? 0;
              final returned =
                  (item['returned_quantity'] as num?)?.toDouble() ?? 0;
              final remaining =
                  (initial - returned).clamp(0.0, double.infinity).toDouble();
              final currentRate = _currentRate(item, rates);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['product_name']?.toString() ?? 'Malzeme',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            StatusPill(
                              label: remaining > 0 ? 'Kirada' : 'Tamamlandı',
                              tone: remaining > 0
                                  ? AppStatusTone.success
                                  : AppStatusTone.neutral,
                              compact: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MiniMetric(
                                label: 'Gönderilen',
                                value:
                                    '${_n(initial)} ${_unit(item['unit'])}',
                              ),
                            ),
                            Expanded(
                              child: _MiniMetric(
                                label: 'Gelen',
                                value:
                                    '${_n(returned)} ${_unit(item['unit'])}',
                              ),
                            ),
                            Expanded(
                              child: _MiniMetric(
                                label: 'Müşteride',
                                value:
                                    '${_n(remaining)} ${_unit(item['unit'])}',
                                emphasize: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (initial > 0)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: (returned / initial).clamp(0.0, 1.0),
                              minHeight: 7,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentRate == null
                                    ? 'Fiyat girilmedi'
                                    : 'Güncel fiyat: ${_money(_double(currentRate['amount']))} ₺ • '
                                        '${currentRate['rate_type'] == 'fixed_monthly' ? 'Sabit aylık' : 'Birim başına aylık'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: currentRate == null
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (canWrite) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed:
                                    remaining > 0 ? () => _addReturn(item) : null,
                                icon: const Icon(Icons.keyboard_return),
                                label: const Text('Malzeme Geri Al'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _addRate(item),
                                icon: const Icon(Icons.price_change_outlined),
                                label: const Text('Fiyat Güncelle'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 14),
          Text(
            'Hesap Özeti',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _MoneyMetric(
                      label: 'Faturalandırılan',
                      amount: accountTotals.billed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyMetric(
                      label: 'Tahsil Edilen',
                      amount: accountTotals.paid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyMetric(
                      label: 'Kalan',
                      amount: accountTotals.balance,
                      emphasize: accountTotals.balance > 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _movementsTab(
    List<Map<String, dynamic>> movements,
    List<Map<String, dynamic>> items,
  ) {
    if (movements.isEmpty) {
      return const _ScrollableEmpty(
        icon: Icons.timeline_outlined,
        title: 'Henüz hareket yok',
        subtitle: 'Giden ve gelen malzeme hareketleri burada görünecek.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: movements.length,
        itemBuilder: (context, index) {
          final movement = movements[index];
          final item = items.firstWhere(
            (i) =>
                i['id'].toString() ==
                movement['rental_item_id'].toString(),
            orElse: () => {
              'product_name': 'Malzeme',
              'unit': 'piece',
            },
          );
          final inbound = movement['movement_type'] == 'inbound_return';
          final date =
              DateTime.parse(movement['movement_date'].toString());

          return _TimelineTile(
            isLast: index == movements.length - 1,
            icon: inbound ? Icons.south_west : Icons.north_east,
            tone: inbound ? AppStatusTone.success : AppStatusTone.info,
            status: inbound ? 'Gelen' : 'Giden',
            title:
                '${_n(_double(movement['quantity']))} ${_unit(item['unit'])} ${item['product_name']}',
            subtitle: [
              trDate(date),
              if (movement['return_condition'] != null)
                _condition(movement['return_condition'].toString()),
              if (movement['pending_sync'] == true) 'Senkron bekliyor',
            ].join(' • '),
            trailing: canWrite
                ? IconButton(
                    tooltip: 'Bu harekete belge ekle',
                    onPressed: () => _queueDocument(
                      inbound ? 'inbound_delivery' : 'outbound_delivery',
                      movementId: movement['id'].toString(),
                    ),
                    icon: const Icon(Icons.attach_file),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _ratesTab(List<Map<String, dynamic>> rates) {
    if (rates.isEmpty) {
      return const _ScrollableEmpty(
        icon: Icons.price_change_outlined,
        title: 'Henüz fiyat geçmişi yok',
        subtitle: 'Fiyat değişiklikleri tarihçeli olarak burada tutulacak.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: rates.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final rate = rates[index];
          final effective =
              DateTime.parse(rate['effective_from'].toString());

          return Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.price_change_outlined),
              ),
              title: Text(
                '${rate['product_name']} • ${_money(_double(rate['amount']))} ₺',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${trDate(effective)} tarihinden itibaren • '
                '${rate['rate_type'] == 'fixed_monthly' ? 'Sabit aylık' : 'Birim başına aylık'}',
              ),
              trailing: rate['pending_sync'] == true
                  ? const StatusPill(
                      label: 'Bekliyor',
                      tone: AppStatusTone.info,
                      compact: true,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _paymentsTab(
    List<Map<String, dynamic>> billing,
    DateTime nextRenewal,
    AccountTotals totals,
  ) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _MoneyMetric(
                      label: 'Toplam Fatura',
                      amount: totals.billed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyMetric(
                      label: 'Tahsilat',
                      amount: totals.paid,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyMetric(
                      label: 'Kalan',
                      amount: totals.balance,
                      emphasize: totals.balance > 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (canWrite)
            FilledButton.icon(
              onPressed: () => _openBilling(nextRenewal),
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                '${trDate(nextRenewal)} Dönemini Aç / Tahsilat Gir',
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Dönemler',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (billing.isEmpty)
            const _EmptyCard(
              icon: Icons.receipt_long_outlined,
              title: 'Henüz fatura veya tahsilat kaydı yok',
              subtitle: 'Bir kira dönemini açtığında burada görünecek.',
            )
          else
            ...billing.map((period) {
              final renewal =
                  DateTime.parse(period['renewal_date'].toString());
              final billed = _double(period['billed_amount']);
              final paid = _double(period['paid_amount']);
              final balance =
                  (billed - paid).clamp(0.0, double.infinity).toDouble();
              final paymentStatus =
                  period['payment_status']?.toString() ?? 'pending';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => _openBilling(renewal),
                    leading: const CircleAvatar(
                      child: Icon(Icons.receipt_long_outlined),
                    ),
                    title: Text(
                      trDate(renewal),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      'Fatura: ${_money(billed)} ₺ • '
                      'Tahsil: ${_money(paid)} ₺ • '
                      'Kalan: ${_money(balance)} ₺',
                    ),
                    trailing: StatusPill(
                      label: _paymentLabel(paymentStatus),
                      tone: _paymentTone(paymentStatus),
                      compact: true,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _documentsTab(List<Map<String, dynamic>> docs) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        children: [
          if (canWrite)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _queueDocument('contract'),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Kira Sözleşmesi'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _queueDocument('outbound_delivery'),
                  icon: const Icon(Icons.north_east),
                  label: const Text('Giden Belgesi'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _queueDocument('inbound_delivery'),
                  icon: const Icon(Icons.south_west),
                  label: const Text('Gelen Belgesi'),
                ),
              ],
            ),
          if (canWrite) const SizedBox(height: 16),
          if (docs.isEmpty)
            const _EmptyCard(
              icon: Icons.folder_open_outlined,
              title: 'Henüz belge yok',
              subtitle:
                  'Sözleşme ve sevkiyat belgelerini kiralamayla ilişkilendirebilirsin.',
            )
          else
            ...docs.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.attach_file),
                    ),
                    title: Text(
                      doc['original_file_name']?.toString() ?? 'Belge',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      _documentLabel(
                        doc['document_type']?.toString() ?? '',
                      ),
                    ),
                    trailing: StatusPill(
                      label:
                          doc['rental_movement_id'] == null ? 'Kiralama' : 'Hareket',
                      tone: AppStatusTone.neutral,
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _currentRate(
    Map<String, dynamic> item,
    List<Map<String, dynamic>> rates,
  ) {
    final itemRates = rates
        .where(
          (r) =>
              r['rental_item_id'].toString() ==
              item['id'].toString(),
        )
        .toList()
      ..sort(
        (a, b) => DateTime.parse(b['effective_from'].toString())
            .compareTo(DateTime.parse(a['effective_from'].toString())),
      );
    return itemRates.isEmpty ? null : itemRates.first;
  }

  _MaterialTotals _materialTotals(List<Map<String, dynamic>> items) {
    double sent = 0;
    double returned = 0;

    for (final item in items) {
      sent += _double(item['initial_quantity']);
      returned += _double(item['returned_quantity']);
    }

    return _MaterialTotals(
      sent: sent,
      returned: returned,
      remaining: (sent - returned).clamp(0.0, double.infinity).toDouble(),
    );
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      ((value as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  double _double(dynamic value) => (value as num?)?.toDouble() ?? 0;

  String _n(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

  String _money(double value) {
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

  String _paymentLabel(String value) => switch (value) {
        'paid' => 'Ödendi',
        'partial' => 'Kısmi',
        _ => 'Bekliyor',
      };

  AppStatusTone _paymentTone(String value) => switch (value) {
        'paid' => AppStatusTone.success,
        'partial' => AppStatusTone.warning,
        _ => AppStatusTone.danger,
      };

  String _documentLabel(String value) => switch (value) {
        'contract' => 'Kira sözleşmesi',
        'outbound_delivery' => 'Giden sevkiyat belgesi',
        'inbound_delivery' => 'Gelen / iade belgesi',
        _ => 'Diğer belge',
      };

  void _success(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _error(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RentalHero extends StatelessWidget {
  final String customerName;
  final String? addressLabel;
  final DateTime original;
  final DateTime nextRenewal;
  final String invoice;
  final _MaterialTotals totals;
  final VoidCallback? onToggleInvoice;

  const _RentalHero({
    required this.customerName,
    required this.addressLabel,
    required this.original,
    required this.nextRenewal,
    required this.invoice,
    required this.totals,
    required this.onToggleInvoice,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: SifaBrand.ivory,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SifaBrand.softGrey),
                  ),
                  alignment: Alignment.center,
                  child: const SifaBuildingMark(size: 32, gold: false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: SifaBrand.charcoal,
                            ),
                      ),
                      if (addressLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          addressLabel!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: SifaBrand.textGrey,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const StatusPill(
                  label: 'Aktif',
                  tone: AppStatusTone.success,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _HeroMetric(
                    label: 'Gönderilen',
                    value: _compactNumber(totals.sent),
                    icon: Icons.north_east,
                    background: SifaBrand.successBg,
                    foreground: SifaBrand.success,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _HeroMetric(
                    label: 'Gelen',
                    value: _compactNumber(totals.returned),
                    icon: Icons.south_west,
                    background: SifaBrand.infoBg,
                    foreground: SifaBrand.info,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: _HeroMetric(
                    label: 'Müşteride',
                    value: _compactNumber(totals.remaining),
                    icon: Icons.inventory_2_outlined,
                    background: SifaBrand.goldBg,
                    foreground: SifaBrand.deepGold,
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            Row(
              children: [
                Expanded(
                  child: _MetaLine(
                    icon: Icons.north_east,
                    text: 'İlk çıkış ${trDate(original)}',
                  ),
                ),
                Expanded(
                  child: _MetaLine(
                    icon: Icons.event_repeat_outlined,
                    text: 'Sonraki kira ${trDate(nextRenewal)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: Icon(
                  invoice == 'invoice_required'
                      ? Icons.receipt_long_outlined
                      : Icons.money_off_outlined,
                  size: 17,
                ),
                label: Text(
                  invoice == 'invoice_required' ? 'Faturalı' : 'Faturasız',
                ),
                onPressed: onToggleInvoice,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _compactNumber(double value) =>
      value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: SifaBrand.charcoal,
                ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _MiniMetric({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: emphasize ? Theme.of(context).colorScheme.primary : null,
              ),
        ),
      ],
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  final String label;
  final double amount;
  final bool emphasize;

  const _MoneyMetric({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = _formatMoney(amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '$value ₺',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: emphasize
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
          ),
        ),
      ],
    );
  }

  static String _formatMoney(double value) {
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

class _TimelineTile extends StatelessWidget {
  final bool isLast;
  final IconData icon;
  final AppStatusTone tone;
  final String status;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _TimelineTile({
    required this.isLast,
    required this.icon,
    required this.tone,
    required this.status,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Icon(icon, size: 17),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      StatusPill(
                        label: status,
                        tone: tone,
                        compact: true,
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(subtitle),
                  ),
                  trailing: trailing,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              icon,
              size: 34,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScrollableEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ScrollableEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
      children: [
        _EmptyCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
        ),
      ],
    );
  }
}

class _MaterialTotals {
  final double sent;
  final double returned;
  final double remaining;

  const _MaterialTotals({
    required this.sent,
    required this.returned,
    required this.remaining,
  });
}
