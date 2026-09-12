import 'package:flutter/material.dart';

import '../services/customer_api_repository.dart';
import '../services/finance_repository.dart';

class RevenueBreakdownScreen extends StatefulWidget {
  const RevenueBreakdownScreen({super.key});

  @override
  State<RevenueBreakdownScreen> createState() =>
      _RevenueBreakdownScreenState();
}

class _RevenueBreakdownScreenState
    extends State<RevenueBreakdownScreen> {
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
      final result = await repo.revenueEstimate(
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
    final groups = ((data?['groups'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final items = ((data?['items'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tahmini Kira Dağılımı')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Ara',
                hintText: 'Müşteri, şantiye veya malzeme',
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
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrelenmiş Tahmini Aylık Kira',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_money(_double(data?['total_estimated_monthly']))} ₺',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_int(data?['unpriced_item_count'])} '
                      'aktif kalemde fiyat eksik.',
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Bu tutar tahmindir, kesilmiş fatura değildir.',
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
            ...groups.map(
              (g) {
                final groupItems = items.where(
                  (i) =>
                      i['customer_id'] == g['customer_id'] &&
                      i['address_id'] == g['address_id'],
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.apartment_outlined),
                      title: Text(
                        g['customer_name']?.toString() ?? 'Müşteri',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        g['address_label']?.toString() ??
                            'Şantiye seçilmedi',
                      ),
                      trailing: Text(
                        '${_money(_double(g['estimated_monthly_amount']))} ₺',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      children: [
                        ListTile(
                          title: const Text('Aktif kiralık kalem'),
                          trailing: Text(
                            '${_int(g['active_items'])}',
                          ),
                        ),
                        ListTile(
                          title: const Text('Fiyatı eksik'),
                          trailing: Text(
                            '${_int(g['unpriced_items'])}',
                          ),
                        ),
                        const Divider(),
                        ...groupItems.map(
                          (i) => ListTile(
                            dense: true,
                            title: Text(
                              i['product_name']?.toString() ??
                                  'Malzeme',
                            ),
                            subtitle: Text(
                              [
                                'Kirada ${_quantity(i['remaining_quantity'])}',
                                if (i['current_rate'] != null)
                                  'Fiyat ${_money(_double(i['current_rate']))} ₺',
                                if (i['price_missing'] == true)
                                  'FİYAT EKSİK',
                              ].join(' • '),
                            ),
                            trailing: Text(
                              '${_money(_double(i['estimated_monthly_amount']))} ₺',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _int(dynamic value) =>
      (value as num?)?.toInt() ?? 0;

  double _double(dynamic value) =>
      (value as num?)?.toDouble() ?? 0;

  String _quantity(dynamic value) {
    final n = (value as num?)?.toDouble() ?? 0;
    return n == n.roundToDouble()
        ? n.toInt().toString()
        : n.toStringAsFixed(2);
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
