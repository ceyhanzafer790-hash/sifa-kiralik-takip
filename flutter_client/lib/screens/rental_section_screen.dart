import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/rental_api_repository.dart';
import '../services/rental_date_service.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';
import 'rental_tracking_detail_screen.dart';

class RentalSectionScreen extends StatefulWidget {
  final Customer customer;

  const RentalSectionScreen({
    super.key,
    required this.customer,
  });

  @override
  State<RentalSectionScreen> createState() => _RentalSectionScreenState();
}

class _RentalSectionScreenState extends State<RentalSectionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController controller;
  final repo = RentalApiRepository();

  bool loading = true;
  List<Map<String, dynamic>> rentals = [];
  final Map<String, Map<String, dynamic>> detailCache = {};

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 3, vsync: this, initialIndex: 2);
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    try {
      final data = await repo.rentalsForCustomerOfflineFirst(
        widget.customer.id,
      );

      final nextDetails = <String, Map<String, dynamic>>{};
      for (final rental in data) {
        try {
          nextDetails[rental['id'].toString()] =
              await repo.rentalDetailOfflineFirst(
            rental['id'].toString(),
          );
        } catch (_) {
          // Bu kayıt henüz cihazda tam yoksa diğerlerini göstermeye devam et.
        }
      }

      if (mounted) {
        setState(() {
          rentals = data;
          detailCache
            ..clear()
            ..addAll(nextDetails);
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = detailCache.values.toList();
    final outboundCount = _movementCount(details, 'outbound');
    final inboundCount = _movementCount(details, 'inbound_return');
    final activeCount = rentals.where(
      (rental) => rental['status']?.toString() != 'closed',
    ).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kiralama Hareketleri',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              const Divider(
                height: 1,
                thickness: 1,
                color: SifaBrand.gold,
              ),
              TabBar(
                controller: controller,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: SifaBrand.gold,
                indicatorWeight: 3,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                tabs: const [
                  Tab(text: 'Gidenler'),
                  Tab(text: 'Gelenler'),
                  Tab(text: 'Kiralamalar'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: SifaBrand.charcoal,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        const SifaBuildingMark(size: 31),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            widget.customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SectionMetric(
                            label: 'Aktif',
                            value: activeCount,
                            icon: Icons.event_repeat_outlined,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _SectionMetric(
                            label: 'Giden',
                            value: outboundCount,
                            icon: Icons.north_east,
                            emphasize: outboundCount > 0,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _SectionMetric(
                            label: 'Gelen',
                            value: inboundCount,
                            icon: Icons.south_west,
                            success: inboundCount > 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: controller,
              children: [
                _MovementTab(
                  details: details,
                  movementType: 'outbound',
                  onRefresh: _load,
                ),
                _MovementTab(
                  details: details,
                  movementType: 'inbound_return',
                  onRefresh: _load,
                ),
                _TrackingTab(
                  customer: widget.customer,
                  rentals: rentals,
                  detailCache: detailCache,
                  onChanged: _load,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _movementCount(
    List<Map<String, dynamic>> details,
    String type,
  ) {
    var count = 0;
    for (final detail in details) {
      for (final raw in (detail['movements'] as List?) ?? const []) {
        final movement = Map<String, dynamic>.from(raw as Map);
        if (movement['movement_type'] == type) count++;
      }
    }
    return count;
  }
}

class _MovementTab extends StatelessWidget {
  final List<Map<String, dynamic>> details;
  final String movementType;
  final Future<void> Function() onRefresh;

  const _MovementTab({
    required this.details,
    required this.movementType,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Map<String, dynamic>>[];

    for (final detail in details) {
      final items = ((detail['items'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final itemById = {
        for (final item in items) item['id'].toString(): item,
      };

      for (final raw in (detail['movements'] as List?) ?? const []) {
        final movement = Map<String, dynamic>.from(raw as Map);
        if (movement['movement_type'] != movementType) continue;

        final item = itemById[movement['rental_item_id'].toString()];
        rows.add({
          ...movement,
          'product_name': item?['product_name'] ?? 'Malzeme',
          'unit': item?['unit'] ?? 'piece',
        });
      }
    }

    rows.sort(
      (a, b) => DateTime.parse(b['movement_date'].toString())
          .compareTo(DateTime.parse(a['movement_date'].toString())),
    );

    final outbound = movementType == 'outbound';

    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(
                      outbound
                          ? Icons.north_east
                          : Icons.south_west,
                      size: 36,
                      color: SifaBrand.deepGold,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      outbound
                          ? 'Giden kiralık malzeme kaydı yok.'
                          : 'Gelen iade kaydı yok.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 7),
        itemBuilder: (context, index) {
          final row = rows[index];
          final date = DateTime.parse(row['movement_date'].toString());
          final condition = row['return_condition']?.toString();

          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: outbound
                      ? SifaBrand.goldBg
                      : SifaBrand.successBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  outbound ? Icons.north_east : Icons.south_west,
                  color: outbound
                      ? SifaBrand.deepGold
                      : SifaBrand.success,
                  size: 21,
                ),
              ),
              title: Text(
                '${_number(row['quantity'])} '
                '${_unitLabel(row['unit']?.toString())} '
                '${row['product_name']}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                '${outbound ? "Çıkış" : "İade"}: ${trDate(date)}'
                '${condition == null ? "" : " • ${_conditionLabel(condition)}"}',
              ),
              trailing: condition == null
                  ? null
                  : StatusPill(
                      label: _conditionLabel(condition),
                      tone: condition == 'repair'
                          ? AppStatusTone.warning
                          : condition == 'scrap'
                              ? AppStatusTone.danger
                              : AppStatusTone.success,
                      compact: true,
                    ),
            ),
          );
        },
      ),
    );
  }

  static String _number(dynamic value) {
    final n = (value as num?)?.toDouble() ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString();
    final fixed = n.toStringAsFixed(2);
    return fixed.endsWith('0')
        ? fixed.substring(0, fixed.length - 1)
        : fixed;
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

  static String _conditionLabel(String value) => switch (value) {
        'repair' => 'Tamirlik',
        'scrap' => 'Hurda',
        _ => 'Kullanılabilir',
      };
}

class _TrackingTab extends StatelessWidget {
  final Customer customer;
  final List<Map<String, dynamic>> rentals;
  final Map<String, Map<String, dynamic>> detailCache;
  final Future<void> Function() onChanged;

  const _TrackingTab({
    required this.customer,
    required this.rentals,
    required this.detailCache,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (rentals.isEmpty) {
      return RefreshIndicator(
        onRefresh: onChanged,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: const [
            Card(
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 36,
                      color: SifaBrand.textGrey,
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Kiralama kaydı yok.',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: rentals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final rental = rentals[index];
          final id = rental['id'].toString();
          final original = DateTime.parse(
            rental['original_outbound_date'].toString(),
          );
          final nextRental = nextMonthlyRentalDate(
            original,
            DateTime.now(),
          );
          final detail = detailCache[id];

          final itemSummaries = <String>[];
          double remainingTotal = 0;

          if (detail != null) {
            final items = ((detail['items'] as List?) ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map));

            for (final item in items) {
              final initial =
                  (item['initial_quantity'] as num?)?.toDouble() ?? 0;
              final returned =
                  (item['returned_quantity'] as num?)?.toDouble() ?? 0;
              final remaining = (initial - returned)
                  .clamp(0.0, double.infinity)
                  .toDouble();

              if (remaining > 0) {
                remainingTotal += remaining;
                itemSummaries.add(
                  '${item['product_name']}: '
                  '${_MovementTab._number(remaining)} '
                  '${_MovementTab._unitLabel(item['unit']?.toString())}',
                );
              }
            }
          }

          final pending = rental['pending_sync'] == true;
          final closed = rental['status']?.toString() == 'closed';

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RentalTrackingDetailScreen(
                      recordId: id,
                    ),
                  ),
                );
                await onChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: closed
                            ? SifaBrand.ivory
                            : SifaBrand.goldBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        pending
                            ? Icons.cloud_upload_outlined
                            : Icons.event_repeat_outlined,
                        color: closed
                            ? SifaBrand.textGrey
                            : SifaBrand.deepGold,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'İlk çıkış: ${trDate(original)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              StatusPill(
                                label: closed ? 'Tamamlandı' : 'Aktif',
                                tone: closed
                                    ? AppStatusTone.neutral
                                    : AppStatusTone.success,
                                compact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (itemSummaries.isNotEmpty)
                            Text(
                              itemSummaries.take(3).join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(
                              detail == null
                                  ? 'Detay cihazda hazırlanıyor…'
                                  : 'Müşteride malzeme kalmadı.',
                              style: const TextStyle(
                                color: SifaBrand.textGrey,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Sonraki kira: ${trDate(nextRental)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: SifaBrand.textGrey,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              if (remainingTotal > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SifaBrand.goldBg,
                                    borderRadius:
                                        BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Kalan ${_MovementTab._number(remainingTotal)}',
                                    style: const TextStyle(
                                      color: SifaBrand.deepGold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (pending) ...[
                            const SizedBox(height: 5),
                            const Text(
                              'Senkron bekliyor',
                              style: TextStyle(
                                color: SifaBrand.info,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.chevron_right,
                      color: SifaBrand.deepGold,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final bool emphasize;
  final bool success;

  const _SectionMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
    this.success = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = success
        ? SifaBrand.success
        : emphasize
            ? SifaBrand.deepGold
            : SifaBrand.charcoal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: success
            ? SifaBrand.successBg
            : emphasize
                ? SifaBrand.goldBg
                : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: success
              ? SifaBrand.success.withOpacity(0.25)
              : emphasize
                  ? SifaBrand.gold.withOpacity(0.35)
                  : SifaBrand.softGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(height: 6),
          Text(
            value.toString(),
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: SifaBrand.textGrey,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
