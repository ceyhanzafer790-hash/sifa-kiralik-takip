import 'package:flutter/material.dart';

import '../services/customer_api_repository.dart';
import '../services/finance_repository.dart';
import '../widgets/sifa_brand.dart';
import 'billing_period_screen.dart';
import 'receivable_aging_screen.dart';
import 'overdue_receivables_screen.dart';

class ReceivablesScreen extends StatefulWidget {
  final bool paymentMode;

  const ReceivablesScreen({
    super.key,
    this.paymentMode = false,
  });

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  final repo = FinanceRepository();
  final customersRepo = CustomerApiRepository();
  final searchController = TextEditingController();

  Map<String, dynamic>? data;
  List<Map<String, dynamic>> customers = [];

  String? customerId;
  String? customerName;
  DateTimeRange? dateRange;

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      customers = await customersRepo.list();
    } catch (_) {
      customers = [];
    }
    await _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final result = await repo.receivables(
        customerId: customerId,
        query: searchController.text,
        fromDate: dateRange?.start,
        toDate: dateRange?.end,
      );
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _chooseCustomer() async {
    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Müşteri Filtresi'),
        children: [
          ListTile(
            title: const Text('Tüm müşteriler'),
            onTap: () => Navigator.pop(
              context,
              <String, dynamic>{},
            ),
          ),
          ...customers.map(
            (c) => ListTile(
              title: Text(c['name'].toString()),
              subtitle: c['phone'] == null
                  ? null
                  : Text(c['phone'].toString()),
              onTap: () => Navigator.pop(context, c),
            ),
          ),
        ],
      ),
    );

    if (selected == null) return;

    setState(() {
      customerId = selected['id']?.toString();
      customerName = selected['name']?.toString();
    });
    await _load();
  }

  Future<void> _chooseDates() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dateRange,
    );

    if (selected == null) return;
    setState(() => dateRange = selected);
    await _load();
  }

  void _clear() {
    setState(() {
      customerId = null;
      customerName = null;
      dateRange = null;
      searchController.clear();
    });
    _load();
  }

  Future<void> _openPeriod(Map<String, dynamic> row) async {
    final rentalId = row['rental_record_id']?.toString();
    final renewalDate =
        DateTime.tryParse(row['renewal_date']?.toString() ?? '');

    if (rentalId == null || renewalDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kira dönemi bilgisi açılamadı.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BillingPeriodScreen(
          rentalId: rentalId,
          renewalDate: renewalDate,
          paymentFocus: widget.paymentMode,
        ),
      ),
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = ((data?['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.paymentMode ? 'Tahsilat Gir' : 'Açık Alacaklar',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: SifaBrand.gold,
          ),
        ),
        actions: [
          if (!widget.paymentMode)
            IconButton(
              tooltip: 'Alacak yaşlandırma',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ReceivableAgingScreen(),
                ),
              ),
              icon: const Icon(Icons.timelapse_outlined),
            ),
          if (!widget.paymentMode)
            IconButton(
              tooltip: 'Vadesi geçmiş alacaklar',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OverdueReceivablesScreen(),
                ),
              ),
              icon: const Icon(Icons.warning_amber_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (widget.paymentMode) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SifaBrand.goldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: SifaBrand.gold.withOpacity(0.35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      color: SifaBrand.deepGold,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Tahsilat gireceğin açık hesabı seç.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: SifaBrand.charcoal,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: SifaBrand.gold.withOpacity(0.45),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: SifaBrand.gold,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Toplam Açık Alacak',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '${_money(_double(data?['total_balance']))} ₺',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: SifaBrand.gold,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Müşteri, şantiye veya fatura no ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Ara',
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _chooseCustomer,
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(customerName ?? 'Müşteri'),
                ),
                OutlinedButton.icon(
                  onPressed: _chooseDates,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    dateRange == null
                        ? 'Dönem'
                        : '${_shortDate(dateRange!.start)} - '
                            '${_shortDate(dateRange!.end)}',
                  ),
                ),
                if (customerId != null ||
                    dateRange != null ||
                    searchController.text.trim().isNotEmpty)
                  TextButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.clear),
                    label: const Text('Temizle'),
                  ),
              ],
            ),
            if (loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(error!),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.paymentMode
                        ? 'Tahsilat Bekleyenler'
                        : 'Açık Hesaplar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: SifaBrand.goldBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: SifaBrand.deepGold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (!loading && items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.task_alt,
                        size: 36,
                        color: SifaBrand.deepGold,
                      ),
                      const SizedBox(height: 9),
                      Text(
                        widget.paymentMode
                            ? 'Tahsil edilecek açık hesap yok.'
                            : 'Bu filtrelerde açık alacak yok.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _openPeriod(row),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                Icons.payments_outlined,
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
                                    row['customer_name']?.toString() ??
                                        'Müşteri',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15.5,
                                    ),
                                  ),
                                  if (row['address_label'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      row['address_label'].toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                  const SizedBox(height: 7),
                                  Text(
                                    'Dönem: ${_date(row['renewal_date'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    [
                                      if (row['invoice_no'] != null)
                                        'Fatura ${row['invoice_no']}',
                                      '${_money(_double(row['billed_amount']))} ₺ fatura',
                                      '${_money(_double(row['paid_amount']))} ₺ tahsil',
                                    ].join(' • '),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: SifaBrand.textGrey,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_money(_double(row['balance_amount']))} ₺',
                                  style: const TextStyle(
                                    color: SifaBrand.charcoal,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SifaBrand.goldBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    widget.paymentMode
                                        ? 'Tahsilat'
                                        : 'Açık',
                                    style: const TextStyle(
                                      color: SifaBrand.deepGold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _double(dynamic value) => (value as num?)?.toDouble() ?? 0;

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw.toString());
    return d == null ? raw.toString() : _shortDate(d);
  }

  String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final chars = parts[0].split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < chars.length; i += 3) {
      groups.add(
        chars.skip(i).take(3).toList().reversed.join(),
      );
    }

    final whole = groups.reversed.join('.');
    return parts[1] == '00' ? whole : '$whole,${parts[1]}';
  }
}
