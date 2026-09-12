import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_config.dart';
import '../services/customer_api_repository.dart';
import '../services/local_domain_cache.dart';
import '../services/role_service.dart';
import 'customer_create_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final repo = CustomerApiRepository();
  final cache = LocalDomainCache();
  final roles = RoleService();

  String query = '';
  bool canWrite = false;
  bool loading = true;
  List<Customer> customers = [];

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
    setState(() => loading = true);

    final local = await cache.customers();
    final localCustomers = local
        .map((r) => Customer(id: r.id, name: r.name))
        .toList();

    if (mounted && localCustomers.isNotEmpty) {
      setState(() => customers = localCustomers);
    }

    if (ApiConfig.configured) {
      try {
        final cloud = await repo.list();
        final cloudCustomers = cloud
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

        if (mounted) setState(() => customers = cloudCustomers);
      } catch (_) {
        // offline cache remains visible
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _createCustomer() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CustomerCreateScreen(),
      ),
    );
    if (id != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = customers
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: _createCustomer,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Müşteri Ekle'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Müşteri ara',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 90),
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 54,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          query.trim().isEmpty
                              ? 'Henüz müşteri kaydı yok.'
                              : 'Aramaya uyan müşteri bulunamadı.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (query.trim().isEmpty && canWrite) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Sağ alttaki Müşteri Ekle düğmesiyle ilk gerçek kaydı oluşturabilirsiniz.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final customer = filtered[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                customer.name.isEmpty
                                    ? '?'
                                    : customer.name.substring(0, 1).toUpperCase(),
                              ),
                            ),
                            title: Text(
                              customer.name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text('Satılanlar • Kiralananlar'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailScreen(
                                    customer: customer,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
