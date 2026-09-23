import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_config.dart';
import '../services/customer_api_repository.dart';
import '../services/local_domain_cache.dart';
import '../services/role_service.dart';
import '../widgets/status_pill.dart';
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
  Map<String, int> activeRentalsByCustomer = {};

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
    if (mounted) setState(() => loading = true);

    final local = await cache.customers();
    final localCustomers = local
        .map((r) => Customer(id: r.id, name: r.name))
        .toList();

    if (mounted && localCustomers.isNotEmpty) {
      setState(() => customers = localCustomers);
      await _loadStats(localCustomers);
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
        await _loadStats(cloudCustomers);
      } catch (_) {
        // Offline cache görünür kalır.
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadStats(List<Customer> values) async {
    final stats = <String, int>{};

    for (final customer in values) {
      final rentals = await cache.rentalsForCustomer(customer.id);
      stats[customer.id] =
          rentals.where((r) => r.status == 'active').length;
    }

    if (mounted) {
      setState(() => activeRentalsByCustomer = stats);
    }
  }

  Future<void> _createCustomer() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const CustomerCreateScreen(),
      ),
    );

    if (id != null) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Müşteri kaydedildi.'),
          ),
        );
      }
    }
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
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Müşteriler',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${customers.length} müşteri • kiralama ve hesap görünümü',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (canWrite)
                      FilledButton.tonalIcon(
                        onPressed: _createCustomer,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Ekle'),
                      ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _CustomerSearchHeader(
                query: query,
                onChanged: (value) => setState(() => query = value),
                loading: loading,
              ),
            ),
            if (!loading && filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 50,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          query.trim().isEmpty
                              ? 'Henüz müşteri kaydı yok.'
                              : 'Aramana uyan müşteri bulunamadı.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    final active = activeRentalsByCustomer[customer.id] ?? 0;

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailScreen(
                                customer: customer,
                              ),
                            ),
                          );
                          await _loadStats(customers);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 23,
                                child: Text(
                                  customer.name.isEmpty
                                      ? '?'
                                      : customer.name
                                          .substring(0, 1)
                                          .toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      active > 0
                                          ? '$active aktif kiralama'
                                          : 'Aktif kiralama yok',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(
                                label: active > 0 ? 'Aktif' : 'Pasif',
                                tone: active > 0
                                    ? AppStatusTone.success
                                    : AppStatusTone.neutral,
                                compact: true,
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerSearchHeader extends SliverPersistentHeaderDelegate {
  final String query;
  final ValueChanged<String> onChanged;
  final bool loading;

  const _CustomerSearchHeader({
    required this.query,
    required this.onChanged,
    required this.loading,
  });

  @override
  double get minExtent => 68;

  @override
  double get maxExtent => 68;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 5, 16, 8),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            TextFormField(
              initialValue: query,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Müşteri ara',
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: onChanged,
            ),
            if (loading)
              const Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CustomerSearchHeader oldDelegate) {
    return oldDelegate.query != query ||
        oldDelegate.loading != loading;
  }
}
