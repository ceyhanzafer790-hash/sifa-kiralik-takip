import 'package:flutter/material.dart';

import '../services/customer_api_repository.dart';
import '../services/finance_repository.dart';
import 'rental_tracking_detail_screen.dart';

class ReceivableAgingScreen extends StatefulWidget {
  const ReceivableAgingScreen({super.key});

  @override
  State<ReceivableAgingScreen> createState() =>
      _ReceivableAgingScreenState();
}

class _ReceivableAgingScreenState
    extends State<ReceivableAgingScreen> {
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
      final result = await repo.receivableAging(
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
      appBar: AppBar(title: const Text('Alacak Yaşlandırma')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Yaş hesabında fatura tarihi varsa o, yoksa kira dönem '
                  'tarihi kullanılır. Bu ekran ödeme vadesi iddiasında bulunmaz.',
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
                  title: '0-30 gün',
                  data: _map(buckets['0_30']),
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
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                title: const Text(
                  '31+ Günlük Açık Alacak',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${_int(data?['aged_31_plus_count'])} açık dönem',
                ),
                trailing: Text(
                  '${_money(_double(data?['aged_31_plus_balance']))} ₺',
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
                    'Bu filtrelerde açık kesilmiş fatura alacağı yok.',
                  ),
                ),
              ),
            ...items.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${_int(r['age_days'])}'),
                    ),
                    title: Text(
                      r['customer_name']?.toString() ?? 'Müşteri',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Text(
                      [
                        if (r['address_label'] != null)
                          r['address_label'].toString(),
                        'Yaş: ${_int(r['age_days'])} gün',
                        if (r['invoice_no'] != null)
                          'Fatura: ${r['invoice_no']}',
                      ].join(' • '),
                    ),
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
