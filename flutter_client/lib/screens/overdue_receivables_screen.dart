import 'package:flutter/material.dart';

import '../services/customer_api_repository.dart';
import '../services/finance_repository.dart';
import 'rental_tracking_detail_screen.dart';

class OverdueReceivablesScreen extends StatefulWidget {
  const OverdueReceivablesScreen({super.key});

  @override
  State<OverdueReceivablesScreen> createState() =>
      _OverdueReceivablesScreenState();
}

class _OverdueReceivablesScreenState
    extends State<OverdueReceivablesScreen> {
  final repo = FinanceRepository();
  final customersRepo = CustomerApiRepository();
  final searchController = TextEditingController();

  Map<String, dynamic>? data;
  List<Map<String, dynamic>> customers = [];
  String? customerId;
  String? customerName;
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
      final result = await repo.overdueReceivables(
        asOf: DateTime.now(),
        customerId: customerId,
        query: searchController.text,
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

  void _clear() {
    setState(() {
      customerId = null;
      customerName = null;
      searchController.clear();
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final buckets = data?['buckets'] is Map
        ? Map<String, dynamic>.from(data!['buckets'] as Map)
        : <String, dynamic>{};

    final items = ((data?['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Vadesi Geçmiş Alacaklar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Bu ekran yalnız ödeme vadesi girilmiş, vadesi geçmiş ve '
                  'bakiyesi açık kesilmiş faturaları gösterir.',
                ),
              ),
            ),
            const SizedBox(height: 10),
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
                TextButton(
                  onPressed: _clear,
                  child: const Text('Filtreyi Temizle'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _BucketCard(
                  title: '1-30 gün',
                  data: _map(buckets['1_30']),
                ),
                _BucketCard(
                  title: '31-60 gün',
                  data: _map(buckets['31_60']),
                ),
                _BucketCard(
                  title: '61+ gün',
                  data: _map(buckets['61_plus']),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: const Text(
                  'Toplam Vadesi Geçmiş',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${_int(data?['total_overdue_count'])} açık dönem',
                ),
                trailing: Text(
                  '${_money(_double(data?['total_overdue_balance']))} ₺',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Vadesi girilmemiş açık fatura'),
                trailing: Text(
                  '${_int(data?['due_date_missing_open_invoice_count'])}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
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
                    'Bu filtrelerde vadesi geçmiş açık fatura yok.',
                  ),
                ),
              ),
            ...items.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${_int(r['overdue_days'])}'),
                    ),
                    title: Text(
                      r['customer_name']?.toString() ?? 'Müşteri',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      [
                        if (r['address_label'] != null)
                          r['address_label'].toString(),
                        'Vade: ${_date(r['payment_due_date'])}',
                        '${_int(r['overdue_days'])} gün gecikmiş',
                        if (r['invoice_no'] != null)
                          'Fatura: ${r['invoice_no']}',
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

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};

  int _int(dynamic value) =>
      (value as num?)?.toInt() ?? 0;

  double _double(dynamic value) =>
      (value as num?)?.toDouble() ?? 0;

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return raw.toString();
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
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

class _BucketCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _BucketCard({
    required this.title,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final count = (data['count'] as num?)?.toInt() ?? 0;
    final balance = (data['balance'] as num?)?.toDouble() ?? 0;

    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text('$count dönem'),
              const SizedBox(height: 4),
              Text(
                '${_money(balance)} ₺',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
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
