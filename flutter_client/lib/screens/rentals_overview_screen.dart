import 'package:flutter/material.dart';

import '../services/local_domain_cache.dart';
import '../services/rental_date_service.dart';
import '../widgets/status_pill.dart';
import '../widgets/sifa_brand.dart';
import 'rental_tracking_detail_screen.dart';

enum _RentalFilter {
  active,
  completed,
  missingDocument,
  receivable,
}

class RentalsOverviewScreen extends StatefulWidget {
  final bool returnMode;

  const RentalsOverviewScreen({
    super.key,
    this.returnMode = false,
  });

  @override
  State<RentalsOverviewScreen> createState() => _RentalsOverviewScreenState();
}

class _RentalsOverviewScreenState extends State<RentalsOverviewScreen> {
  final cache = LocalDomainCache();

  bool loading = true;
  String query = '';
  _RentalFilter filter = _RentalFilter.active;
  List<_RentalOverviewRow> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    final customers = await cache.customers();
    final products = await cache.products();
    final productById = {for (final p in products) p.id: p};

    final result = <_RentalOverviewRow>[];

    for (final customer in customers) {
      final rentals = await cache.rentalsForCustomer(customer.id);

      for (final rental in rentals) {
        final address = rental.addressId == null
            ? null
            : await cache.address(rental.addressId!);
        final items = await cache.rentalItems(rental.id);
        final movements = await cache.movements(rental.id);
        final documents = await cache.documents(rental.id);
        final pendingDocuments = await cache.pendingDocuments(rental.id);
        final billing = await cache.billingPeriods(rental.id);

        final summaries = <String>[];
        var activeItemCount = 0;
        double remainingTotal = 0;

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
          remainingTotal += remaining;
          final product = productById[item.productId];
          summaries.add(
            '${product?.name ?? 'Malzeme'}: ${_number(remaining.toDouble())} '
            '${_unitLabel(product?.unit)}',
          );
        }

        bool hasDocument(String type, {String? movementId}) {
          final synced = documents.any(
            (d) =>
                d.documentType == type &&
                (movementId == null || d.movementId == movementId),
          );
          final queued = pendingDocuments.any(
            (d) =>
                d['document_type'] == type &&
                (movementId == null ||
                    d['rental_movement_id']?.toString() == movementId),
          );
          return synced || queued;
        }

        var missingDocumentCount = 0;
        if (!hasDocument('contract')) missingDocumentCount++;

        for (final movement in movements) {
          final requiredType = movement.movementType == 'outbound'
              ? 'outbound_delivery'
              : movement.movementType == 'inbound_return'
                  ? 'inbound_delivery'
                  : null;
          if (requiredType == null) continue;
          if (!hasDocument(requiredType, movementId: movement.id)) {
            missingDocumentCount++;
          }
        }

        double receivableBalance = 0;
        for (final period in billing) {
          final billed = period.billedAmount ?? 0;
          final paid = period.paidAmount ?? 0;
          receivableBalance +=
              (billed - paid).clamp(0.0, double.infinity).toDouble();
        }

        result.add(
          _RentalOverviewRow(
            id: rental.id,
            customerName: customer.name,
            addressLabel: address?.label,
            outboundDate: rental.originalOutboundDate,
            summaries: summaries,
            activeItemCount: activeItemCount,
            remainingTotal: remainingTotal,
            pendingSync: rental.pendingSync,
            active: rental.status == 'active',
            missingDocumentCount: missingDocumentCount,
            receivableBalance: receivableBalance,
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

  List<_RentalOverviewRow> get _filtered {
    final q = query.trim().toLowerCase();

    return rows.where((row) {
      final matchesQuery = q.isEmpty ||
          row.customerName.toLowerCase().contains(q) ||
          (row.addressLabel?.toLowerCase().contains(q) ?? false) ||
          row.summaries.any((s) => s.toLowerCase().contains(q));

      if (!matchesQuery) return false;

      return switch (filter) {
        _RentalFilter.active => row.active,
        _RentalFilter.completed => !row.active,
        _RentalFilter.missingDocument => row.missingDocumentCount > 0,
        _RentalFilter.receivable => row.receivableBalance > 0,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      appBar: widget.returnMode
          ? AppBar(
              title: const Text(
                'Malzeme Geri Al',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: SifaBrand.gold,
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.returnMode
                          ? 'Aktif Kiralamayı Seç'
                          : 'Kiralamalar',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.returnMode
                          ? 'İade gelecek müşteriyi veya şantiyeyi seç.'
                          : 'Kimde ne var, ne eksik ve hangi hesap açık tek yerde.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (loading) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchFilterHeader(
                query: query,
                filter: filter,
                returnMode: widget.returnMode,
                onQueryChanged: (value) => setState(() => query = value),
                onFilterChanged: (value) => setState(() => filter = value),
                counts: {
                  _RentalFilter.active: rows.where((r) => r.active).length,
                  _RentalFilter.completed: rows.where((r) => !r.active).length,
                  _RentalFilter.missingDocument:
                      rows.where((r) => r.missingDocumentCount > 0).length,
                  _RentalFilter.receivable:
                      rows.where((r) => r.receivableBalance > 0).length,
                },
              ),
            ),
            if (!loading && filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_alt_off_outlined,
                          size: 46,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Bu filtrede kiralama bulunamadı.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800),
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
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final row = filtered[index];
                    final nextRental =
                        nextMonthlyRentalDate(row.outboundDate, DateTime.now());

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RentalTrackingDetailScreen(
                                recordId: row.id,
                                focusReturn: widget.returnMode,
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
                                        if (row.addressLabel != null) ...[
                                          const SizedBox(height: 2),
                                          Text(row.addressLabel!),
                                        ],
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    label: row.active ? 'Aktif' : 'Tamamlandı',
                                    tone: row.active
                                        ? AppStatusTone.success
                                        : AppStatusTone.neutral,
                                    compact: true,
                                  ),
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
                                  '+${row.summaries.length - 3} kalem daha',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              const Divider(height: 24),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _Meta(
                                    icon: Icons.north_east,
                                    text:
                                        'İlk çıkış ${trDate(row.outboundDate)}',
                                  ),
                                  if (row.active)
                                    _Meta(
                                      icon: Icons.event_repeat_outlined,
                                      text:
                                          'Sonraki kira ${trDate(nextRental)}',
                                    ),
                                  _Meta(
                                    icon: Icons.inventory_2_outlined,
                                    text:
                                        '${row.activeItemCount} aktif kalem',
                                  ),
                                  if (row.missingDocumentCount > 0)
                                    StatusPill(
                                      label:
                                          '${row.missingDocumentCount} eksik belge',
                                      tone: AppStatusTone.warning,
                                      icon: Icons.description_outlined,
                                      compact: true,
                                    ),
                                  if (row.receivableBalance > 0)
                                    StatusPill(
                                      label:
                                          '${_money(row.receivableBalance)} ₺ açık',
                                      tone: AppStatusTone.danger,
                                      icon:
                                          Icons.account_balance_wallet_outlined,
                                      compact: true,
                                    ),
                                  if (row.pendingSync)
                                    const StatusPill(
                                      label: 'Senkron bekliyor',
                                      tone: AppStatusTone.info,
                                      icon: Icons.cloud_upload_outlined,
                                      compact: true,
                                    ),
                                ],
                              ),
                              if (row.remainingTotal > 0) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Toplam kalan miktar: ${_number(row.remainingTotal)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    if (widget.returnMode)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: SifaBrand.goldBg,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.keyboard_return,
                                              size: 15,
                                              color: SifaBrand.deepGold,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              'İade Seç',
                                              style: TextStyle(
                                                color: SifaBrand.deepGold,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
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
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final chars = parts[0].split('').reversed.toList();
    final groups = <String>[];
    for (var i = 0; i < chars.length; i += 3) {
      groups.add(chars.skip(i).take(3).toList().reversed.join());
    }
    final whole = groups.reversed.join('.');
    return parts[1] == '00' ? whole : '$whole,${parts[1]}';
  }

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

class _SearchFilterHeader extends SliverPersistentHeaderDelegate {
  final String query;
  final _RentalFilter filter;
  final bool returnMode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_RentalFilter> onFilterChanged;
  final Map<_RentalFilter, int> counts;

  const _SearchFilterHeader({
    required this.query,
    required this.filter,
    required this.returnMode,
    required this.onQueryChanged,
    required this.onFilterChanged,
    required this.counts,
  });

  @override
  double get minExtent => returnMode ? 62 : 122;

  @override
  double get maxExtent => returnMode ? 62 : 122;

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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: TextFormField(
                initialValue: query,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Müşteri, şantiye veya malzeme ara',
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: onQueryChanged,
              ),
            ),
            if (!returnMode) ...[
              const SizedBox(height: 7),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(
                      _RentalFilter.active,
                      'Aktif',
                      Icons.circle_outlined,
                    ),
                    _filterChip(
                      _RentalFilter.completed,
                      'Tamamlandı',
                      Icons.check_circle_outline,
                    ),
                    _filterChip(
                      _RentalFilter.missingDocument,
                      'Eksik Belgeli',
                      Icons.description_outlined,
                    ),
                    _filterChip(
                      _RentalFilter.receivable,
                      'Tahsilat Bekleyen',
                      Icons.payments_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip(
    _RentalFilter value,
    String label,
    IconData icon,
  ) {
    final selected = filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        selected: selected,
        avatar: Icon(icon, size: 16),
        label: Text('$label (${counts[value] ?? 0})'),
        onSelected: (_) => onFilterChanged(value),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchFilterHeader oldDelegate) {
    return oldDelegate.query != query ||
        oldDelegate.filter != filter ||
        oldDelegate.returnMode != returnMode ||
        oldDelegate.counts.toString() != counts.toString();
  }
}

class _RentalOverviewRow {
  final String id;
  final String customerName;
  final String? addressLabel;
  final DateTime outboundDate;
  final List<String> summaries;
  final int activeItemCount;
  final double remainingTotal;
  final bool pendingSync;
  final bool active;
  final int missingDocumentCount;
  final double receivableBalance;

  const _RentalOverviewRow({
    required this.id,
    required this.customerName,
    required this.addressLabel,
    required this.outboundDate,
    required this.summaries,
    required this.activeItemCount,
    required this.remainingTotal,
    required this.pendingSync,
    required this.active,
    required this.missingDocumentCount,
    required this.receivableBalance,
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
