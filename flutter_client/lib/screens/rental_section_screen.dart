import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/rental_api_repository.dart';
import '../services/rental_date_service.dart';
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
    setState(() => loading = true);
    try {
      final data = await repo.rentalsForCustomerOfflineFirst(
        widget.customer.id,
      );
      if (mounted) setState(() => rentals = data);

      for (final r in data) {
        try {
          detailCache[r['id'].toString()] =
              await repo.rentalDetailOfflineFirst(r['id'].toString());
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.customer.name} • Kiralananlar'),
        bottom: TabBar(
          controller: controller,
          tabs: const [
            Tab(text: 'Gidenler'),
            Tab(text: 'Gelenler'),
            Tab(text: 'Kiralama Takibi'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: controller,
              children: [
                _MovementTab(
                  details: detailCache.values.toList(),
                  movementType: 'outbound',
                ),
                _MovementTab(
                  details: detailCache.values.toList(),
                  movementType: 'inbound_return',
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
}

class _MovementTab extends StatelessWidget {
  final List<Map<String, dynamic>> details;
  final String movementType;

  const _MovementTab({
    required this.details,
    required this.movementType,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Map<String, dynamic>>[];

    for (final detail in details) {
      final rental = Map<String, dynamic>.from(detail['rental'] as Map);
      final items = ((detail['items'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final itemById = {
        for (final i in items) i['id'].toString(): i,
      };

      for (final raw in (detail['movements'] as List?) ?? const []) {
        final m = Map<String, dynamic>.from(raw as Map);
        if (m['movement_type'] != movementType) continue;

        final item = itemById[m['rental_item_id'].toString()];
        rows.add({
          ...m,
          'product_name': item?['product_name'] ?? 'Malzeme',
          'unit': item?['unit'] ?? 'piece',
          'original_outbound_date':
              rental['original_outbound_date'],
        });
      }
    }

    rows.sort(
      (a, b) => DateTime.parse(b['movement_date'].toString())
          .compareTo(DateTime.parse(a['movement_date'].toString())),
    );

    if (rows.isEmpty) {
      return Center(
        child: Text(
          movementType == 'outbound'
              ? 'Giden kiralık malzeme kaydı yok.'
              : 'Gelen iade kaydı yok.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final row = rows[index];
          final date = DateTime.parse(row['movement_date'].toString());
          final condition = row['return_condition']?.toString();

          return Card(
            child: ListTile(
              leading: Icon(
                movementType == 'outbound'
                    ? Icons.north_east
                    : Icons.south_west,
              ),
              title: Text(
                '${_number(row['quantity'])} '
                '${_unitLabel(row['unit']?.toString())} '
                '${row['product_name']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${movementType == 'outbound' ? "Çıkış" : "İade"}: '
                '${trDate(date)}'
                '${condition == null ? "" : " • ${_conditionLabel(condition)}"}',
              ),
            ),
          );
        },
      ),
    );
  }

  static String _number(dynamic value) {
    final n = (value as num?)?.toDouble() ?? 0;
    return n == n.roundToDouble()
        ? n.toInt().toString()
        : n.toString();
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
      return const Center(child: Text('Kiralama Takibi kaydı yok.'));
    }

    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
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

          String summary = 'Detay cihazda hazırlanıyor…';
          if (detail != null) {
            final items = ((detail['items'] as List?) ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map));

            summary = items.map((i) {
              final initial =
                  (i['initial_quantity'] as num?)?.toDouble() ?? 0;
              final returned =
                  (i['returned_quantity'] as num?)?.toDouble() ?? 0;
              final remaining = initial - returned;
              return '${i['product_name']}: '
                  '${remaining == remaining.roundToDouble() ? remaining.toInt() : remaining} '
                  '${_MovementTab._unitLabel(i['unit']?.toString())} kaldı';
            }).join('\n');
          }

          final pending = rental['pending_sync'] == true;

          return Card(
            child: ListTile(
              isThreeLine: true,
              leading: pending
                  ? const Icon(Icons.cloud_upload_outlined)
                  : const Icon(Icons.event_repeat_outlined),
              title: Text(
                'İlk çıkış: ${trDate(original)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '$summary\nSonraki kira: ${trDate(nextRental)}'
                '${pending ? " • Senkron bekliyor" : ""}',
              ),
              trailing: const Icon(Icons.chevron_right),
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
            ),
          );
        },
      ),
    );
  }
}
