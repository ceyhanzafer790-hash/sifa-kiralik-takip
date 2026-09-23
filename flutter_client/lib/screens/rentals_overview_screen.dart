import 'package:flutter/material.dart';

import '../services/local_domain_cache.dart';
import '../services/rental_date_service.dart';
import 'rental_tracking_detail_screen.dart';

class RentalsOverviewScreen extends StatefulWidget {
  const RentalsOverviewScreen({super.key});

  @override
  State<RentalsOverviewScreen> createState() => _RentalsOverviewScreenState();
}

class _RentalsOverviewScreenState extends State<RentalsOverviewScreen> {
  final cache = LocalDomainCache();

  bool loading = true;
  String query = '';
  List<_RentalOverviewRow> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final customers = await cache.customers();
    final products = await cache.products();
    final productById = {for (final p in products) p.id: p};

    final result = <_RentalOverviewRow>[];

    for (final customer in customers) {
      final rentals = await cache.rentalsForCustomer(customer.id);

      for (final rental in rentals.where((r) => r.status == 'active')) {
        final address =
            rental.addressId == null ? null : await cache.address(rental.addressId!);
        final items = await cache.rentalItems(rental.id);
        final movements = await cache.movements(rental.id);

        final summaries = <String>[];
        var activeItemCount = 0;

        for (final item in items) {
          final returned = movements
              .where(
                (m) =>
                    m.rentalItemId == item.id &&
                    m.movementType == 'inbound_return',
              )
              .fold<double>(0, (sum, m) => sum + m.quantity);

          final remaining =
              (item.initialQuantity - returned).clamp(0.0, double.infinity);
          if (remaining <= 0) continue;

          activeItemCount++;
          final product = productById[item.productId];
          summaries.add(
            '${product?.name ?? 'Malzeme'}: ${_number(remaining.toDouble())} '
            '${_unitLabel(product?.unit)}',
          );
        }

        result.add(
          _RentalOverviewRow(
            id: rental.id,
            customerName: customer.name,
            addressLabel: address?.label,
            outboundDate: rental.originalOutboundDate,
            summaries: summaries,
            activeItemCount: activeItemCount,
            pendingSync: rental.pendingSync,
          ),
        );
      }
    }

    result.sort((a, b) => b.outboundDate.compareTo(a.outboundDate));

    if (mounted) {
      setState(() {
        rows = result;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = rows.where((row) {
      if (q.isEmpty) return true;
      return row.customerName.toLowerCase().contains(q) ||
          (row.addressLabel?.toLowerCase().contains(q) ?? false) ||
          row.summaries.any((s) => s.toLowerCase().contains(q));
    }).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiralamalar',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Müşteride bulunan kiralıkları tek ekrandan takip et.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Müşteri, şantiye veya malzeme ara',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => query = value),
                    ),
                    if (loading) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            if (!loading && filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      q.isEmpty
                          ? 'Aktif kiralama görünmüyor.'
                          : 'Aramana uyan kiralama bulunamadı.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    final nextRental =
                        nextMonthlyRentalDate(row.outboundDate, DateTime.now());

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RentalTrackingDetailScreen(
                                recordId: row.id,
                              ),
                            ),
                          );
                          await _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.customerName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        if (row.addressLabel != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(row.addressLabel!),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Chip(label: Text('Aktif')),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (row.summaries.isEmpty)
                                const Text(
                                  'Müşteride kalan malzeme görünmüyor.',
                                )
                              else
                                ...row.summaries.take(3).map(
                                      (s) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          s,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                              if (row.summaries.length > 3)
                                Text(
                                  '+${row.summaries.length - 3} malzeme daha',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const Divider(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  _Meta(
                                    icon: Icons.north_east,
                                    text:
                                        'İlk çıkış ${trDate(row.outboundDate)}',
                                  ),
                                  _Meta(
                                    icon: Icons.event_repeat_outlined,
                                    text:
                                        'Sonraki kira ${trDate(nextRental)}',
                                  ),
                                  _Meta(
                                    icon: Icons.inventory_2_outlined,
                                    text: '${row.activeItemCount} aktif kalem',
                                  ),
                                  if (row.pendingSync)
                                    const _Meta(
                                      icon: Icons.cloud_upload_outlined,
                                      text: 'Senkron bekliyor',
                                    ),
                                ],
                              ),
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

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  static String _unitLabel(String? unit) => switch (unit) {
        'sheet' => 'Levha',
        'meter' => 'Metre',
        'squareMeter' || 'square_meter' => 'm²',
        'cubicMeter' || 'cubic_meter' => 'm³',
        'kilogram' => 'kg',
        'liter' => 'Litre',
        'set' => 'Takım',
        _ => 'Adet',
      };
}

class _RentalOverviewRow {
  final String id;
  final String customerName;
  final String? addressLabel;
  final DateTime outboundDate;
  final List<String> summaries;
  final int activeItemCount;
  final bool pendingSync;

  const _RentalOverviewRow({
    required this.id,
    required this.customerName,
    required this.addressLabel,
    required this.outboundDate,
    required this.summaries,
    required this.activeItemCount,
    required this.pendingSync,
  });
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Meta({
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
