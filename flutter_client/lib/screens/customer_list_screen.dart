import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_config.dart';
import '../services/customer_api_repository.dart';
import '../services/local_domain_cache.dart';
import '../services/rental_date_service.dart';
import '../services/role_service.dart';
import '../widgets/status_pill.dart';
import '../widgets/sifa_brand.dart';
import 'customer_create_screen.dart';
import 'customer_detail_screen.dart';

enum _CustomerSort {
  latestOutbound,
  alphabetic,
}

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
  _CustomerSort sort = _CustomerSort.latestOutbound;

  List<Customer> customers = [];
  Map<String, _CustomerActivity> activityByCustomer = {};

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
      await _loadActivity(localCustomers);
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
        await _loadActivity(cloudCustomers);
      } catch (_) {
        // Offline cache görünür kalır.
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _loadActivity(List<Customer> values) async {
    final products = await cache.products();
    final productById = {for (final p in products) p.id: p};
    final activity = <String, _CustomerActivity>{};

    for (final customer in values) {
      final rentals = await cache.rentalsForCustomer(customer.id);
      final activeRentalCount =
          rentals.where((r) => r.status == 'active').length;

      DateTime? latestOutboundDate;
      final latestMovements = <_OutboundMovementSummary>[];

      for (final rental in rentals) {
        final movements = await cache.movements(rental.id);
        final outbound = movements
            .where((m) => m.movementType == 'outbound')
            .toList();

        if (outbound.isEmpty) {
          // Eski/eksik kayıtta hareket satırı yoksa ilk çıkış tarihi sıralamayı
          // yine doğru tutabilsin.
          final fallbackDate = rental.originalOutboundDate;
          if (latestOutboundDate == null ||
              fallbackDate.isAfter(latestOutboundDate)) {
            latestOutboundDate = fallbackDate;
            latestMovements.clear();

            final items = await cache.rentalItems(rental.id);
            for (final item in items) {
              final product = productById[item.productId];
              latestMovements.add(
                _OutboundMovementSummary(
                  productName: product?.name ?? 'Malzeme',
                  quantity: item.initialQuantity,
                  unit: product?.unit,
                ),
              );
            }
          }
          continue;
        }

        for (final movement in outbound) {
          final movementDate = DateTime(
            movement.movementDate.year,
            movement.movementDate.month,
            movement.movementDate.day,
          );

          if (latestOutboundDate == null ||
              movementDate.isAfter(latestOutboundDate)) {
            latestOutboundDate = movementDate;
            latestMovements.clear();
          }

          if (_sameDay(movementDate, latestOutboundDate)) {
            final product = productById[movement.productId];
            latestMovements.add(
              _OutboundMovementSummary(
                productName: product?.name ?? 'Malzeme',
                quantity: movement.quantity,
                unit: product?.unit,
              ),
            );
          }
        }
      }

      activity[customer.id] = _CustomerActivity(
        activeRentalCount: activeRentalCount,
        latestOutboundDate: latestOutboundDate,
        latestOutbound: latestMovements,
      );
    }

    if (mounted) {
      setState(() => activityByCustomer = activity);
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

  List<Customer> get _visibleCustomers {
    final q = query.trim().toLowerCase();

    final result = customers
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList();

    switch (sort) {
      case _CustomerSort.latestOutbound:
        result.sort((a, b) {
          final aDate = activityByCustomer[a.id]?.latestOutboundDate;
          final bDate = activityByCustomer[b.id]?.latestOutboundDate;

          if (aDate == null && bDate == null) {
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          }
          if (aDate == null) return 1;
          if (bDate == null) return -1;

          final byDate = bDate.compareTo(aDate);
          if (byDate != 0) return byDate;

          final aActive =
              activityByCustomer[a.id]?.activeRentalCount ?? 0;
          final bActive =
              activityByCustomer[b.id]?.activeRentalCount ?? 0;
          final byActive = bActive.compareTo(aActive);
          if (byActive != 0) return byActive;

          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _CustomerSort.alphabetic:
        result.sort(
          (a, b) =>
              a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _visibleCustomers;

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
                            sort == _CustomerSort.latestOutbound
                                ? 'En yeni malzeme çıkışı en üstte'
                                : 'Müşteriler alfabetik sıralanıyor',
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
                sort: sort,
                onChanged: (value) => setState(() => query = value),
                onSortChanged: (value) => setState(() => sort = value),
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
                          style:
                              const TextStyle(fontWeight: FontWeight.w800),
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
                    final activity =
                        activityByCustomer[customer.id] ??
                            const _CustomerActivity();

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
                          await _loadActivity(customers);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: activity.latestOutboundDate != null &&
                                          DateTime.now()
                                                  .difference(activity.latestOutboundDate!)
                                                  .inDays <=
                                              7
                                      ? SifaBrand.goldBg
                                      : SifaBrand.ivory,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: activity.latestOutboundDate != null &&
                                            DateTime.now()
                                                    .difference(activity.latestOutboundDate!)
                                                    .inDays <=
                                                7
                                        ? SifaBrand.gold.withOpacity(0.35)
                                        : SifaBrand.softGrey,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: SifaBuildingMark(
                                  size: 31,
                                  gold: activity.latestOutboundDate != null &&
                                      DateTime.now()
                                              .difference(activity.latestOutboundDate!)
                                              .inDays <= 7,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            customer.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15.5,
                                            ),
                                          ),
                                        ),
                                        StatusPill(
                                          label:
                                              activity.activeRentalCount > 0
                                                  ? 'Aktif'
                                                  : 'Pasif',
                                          tone:
                                              activity.activeRentalCount > 0
                                                  ? AppStatusTone.success
                                                  : AppStatusTone.neutral,
                                          compact: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (activity.latestOutboundDate != null)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.north_east,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Son çıkış • ${trDate(activity.latestOutboundDate!)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w800,
                                                ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        'Henüz malzeme çıkışı yok',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    if (activity.latestOutbound.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        _outboundSummary(
                                          activity.latestOutbound,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      activity.activeRentalCount > 0
                                          ? '${activity.activeRentalCount} aktif kiralama'
                                          : 'Aktif kiralama yok',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Padding(
                                padding: EdgeInsets.only(top: 18),
                                child: Icon(Icons.chevron_right),
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

  String _outboundSummary(List<_OutboundMovementSummary> movements) {
    final text = movements
        .take(3)
        .map(
          (m) =>
              '${_number(m.quantity)} ${_unit(m.unit)} ${m.productName}',
        )
        .join(' • ');

    if (movements.length <= 3) return text;
    return '$text • +${movements.length - 3} kalem';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

  static String _unit(String? unit) => switch (unit) {
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

class _CustomerSearchHeader extends SliverPersistentHeaderDelegate {
  final String query;
  final _CustomerSort sort;
  final ValueChanged<String> onChanged;
  final ValueChanged<_CustomerSort> onSortChanged;
  final bool loading;

  const _CustomerSearchHeader({
    required this.query,
    required this.sort,
    required this.onChanged,
    required this.onSortChanged,
    required this.loading,
  });

  @override
  double get minExtent => 116;

  @override
  double get maxExtent => 116;

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
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  TextFormField(
                    initialValue: query,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Müşteri ara...',
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10),
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
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    selected: sort == _CustomerSort.latestOutbound,
                    avatar: const Icon(
                      Icons.history_toggle_off,
                      size: 16,
                    ),
                    label: const Text('Son Çıkış'),
                    onSelected: (_) =>
                        onSortChanged(_CustomerSort.latestOutbound),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    selected: sort == _CustomerSort.alphabetic,
                    avatar: const Icon(Icons.sort_by_alpha, size: 16),
                    label: const Text('A–Z'),
                    onSelected: (_) =>
                        onSortChanged(_CustomerSort.alphabetic),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CustomerSearchHeader oldDelegate) {
    return oldDelegate.query != query ||
        oldDelegate.sort != sort ||
        oldDelegate.loading != loading;
  }
}

class _CustomerActivity {
  final int activeRentalCount;
  final DateTime? latestOutboundDate;
  final List<_OutboundMovementSummary> latestOutbound;

  const _CustomerActivity({
    this.activeRentalCount = 0,
    this.latestOutboundDate,
    this.latestOutbound = const [],
  });
}

class _OutboundMovementSummary {
  final String productName;
  final double quantity;
  final String? unit;

  const _OutboundMovementSummary({
    required this.productName,
    required this.quantity,
    required this.unit,
  });
}
