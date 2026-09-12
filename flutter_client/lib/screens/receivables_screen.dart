import 'package:flutter/material.dart';

import '../services/customer_api_repository.dart';
import '../services/finance_repository.dart';
import 'rental_tracking_detail_screen.dart';
import 'receivable_aging_screen.dart';
import 'overdue_receivables_screen.dart';

class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});

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
    setState(() {
      loading = true;
      error = null;
    });

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

  @override
  Widget build(BuildContext context) {
    final items = ((data?['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kesilmiş Fatura Alacakları'),
        actions: [
          IconButton(
            tooltip: 'Alacak yaşlandırma',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReceivableAgingScreen(),
              ),
            ),
            icon: const Icon(Icons.timelapse_outlined),
          ),
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
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Ara',
                hintText: 'Müşteri, şantiye veya fatura no',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: 8),
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
                TextButton(
                  onPressed: _clear,
                  child: const Text('Filtreyi Temizle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filtrelenmiş Açık Alacak',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${_money(_double(data?['total_balance']))} ₺',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(error!),
                ),
              ),
            if (!loading && items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Bu filtrelerde açık kesilmiş fatura alacağı yok.',
                  ),
                ),
              ),
            ...items.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet_outlined,
                    ),
                    title: Text(
                      r['customer_name']?.toString() ?? 'Müşteri',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      [
                        if (r['address_label'] != null)
                          r['address_label'].toString(),
                        'Dönem: ${_date(r['renewal_date'])}',
                        if (r['invoice_no'] != null)
                          'Fatura: ${r['invoice_no']}',
                        'Fatura ${_money(_double(r['billed_amount']))} ₺',
                        'Tahsil ${_money(_double(r['paid_amount']))} ₺',
                      ].join(' • '),
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      '${_money(_double(r['balance_amount']))} ₺',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RentalTrackingDetailScreen(
                          recordId: r['rental_record_id'].toString(),
                        ),
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

  double _double(dynamic value) =>
      (value as num?)?.toDouble() ?? 0;

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
