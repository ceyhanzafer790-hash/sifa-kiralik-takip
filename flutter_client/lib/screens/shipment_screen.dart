import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_config.dart';
import '../services/customer_api_repository.dart';
import '../services/local_domain_cache.dart';
import 'customer_create_screen.dart';
import 'rental_create_screen.dart';

class ShipmentScreen extends StatefulWidget {
  const ShipmentScreen({super.key});

  @override
  State<ShipmentScreen> createState() => _ShipmentScreenState();
}

class _ShipmentScreenState extends State<ShipmentScreen> {
  final repo = CustomerApiRepository();
  final cache = LocalDomainCache();

  bool loading = true;
  String query = '';
  List<Customer> customers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    final local = await cache.customers();
    var result = local
        .map((r) => Customer(id: r.id, name: r.name))
        .toList();

    if (mounted) setState(() => customers = result);

    if (ApiConfig.configured) {
      try {
        final cloud = await repo.list();
        result = cloud
            .map(
              (r) => Customer(
                id: r['id'].toString(),
                name: r['name'].toString(),
              ),
            )
            .toList();

        for (final r in cloud) {
          await cache.upsertCustomer(
            id: r['id'].toString(),
            name: r['name'].toString(),
            phone: r['phone']?.toString(),
            notes: r['notes']?.toString(),
            pendingSync: false,
          );
        }

        if (mounted) setState(() => customers = result);
      } catch (_) {
        // Sunucu yoksa gerçek yerel müşteri cache'i kullanılmaya devam eder.
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _createCustomer() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CustomerCreateScreen()),
    );
    if (id != null) await _load();
  }

  Future<void> _startRental(Customer customer) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RentalCreateScreen(customer: customer),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = customers
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Text(
              'Yeni Sevkiyat',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Kiralık çıkış kaydı oluşturmak için gerçek müşteriyi seçin. '
                  'Kayıt çevrimdışıyken de kaydedilir ve bağlantı geldiğinde senkronlanır.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Müşteri ara',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            if (loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            if (!loading && filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      const Icon(Icons.person_search_outlined, size: 42),
                      const SizedBox(height: 10),
                      Text(
                        q.isEmpty
                            ? 'Henüz gerçek müşteri kaydı yok.'
                            : 'Aramaya uyan müşteri bulunamadı.',
                        textAlign: TextAlign.center,
                      ),
                      if (q.isEmpty) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _createCustomer,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Müşteri Ekle'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              ...filtered.map(
                (customer) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Kiralık çıkış / sevkiyat oluştur'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _startRental(customer),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
