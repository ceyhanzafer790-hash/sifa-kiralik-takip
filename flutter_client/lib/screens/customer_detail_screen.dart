import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/rental_api_repository.dart';
import '../services/rental_date_service.dart';
import '../services/report_download_service.dart';
import '../services/role_service.dart';
import '../widgets/status_pill.dart';
import '../widgets/sifa_brand.dart';
import 'rental_create_screen.dart';
import 'rental_tracking_detail_screen.dart';
import 'sales_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final roles = RoleService();
  final reports = ReportDownloadService();
  final rentalRepo = RentalApiRepository();

  bool canWrite = false;
  bool isAdmin = false;
  bool loading = true;
  String? error;

  int activeRentalCount = 0;
  int activeItemCount = 0;
  double totalRemaining = 0;
  double openBalance = 0;
  List<_CustomerRentalCardData> rentals = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadRole(),
      _loadSummary(),
    ]);
  }

  Future<void> _loadRole() async {
    final result = await Future.wait([
      roles.canWrite(),
      roles.isAdmin(),
    ]);

    if (!mounted) return;
    setState(() {
      canWrite = result[0];
      isAdmin = result[1];
    });
  }

  Future<void> _loadSummary() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final rentalRows =
          await rentalRepo.rentalsForCustomerOfflineFirst(widget.customer.id);
      final cards = <_CustomerRentalCardData>[];
      var nextActiveRentalCount = 0;
      var nextActiveItemCount = 0;
      double nextRemaining = 0;
      double nextOpenBalance = 0;

      for (final rental in rentalRows) {
        final id = rental['id'].toString();

        try {
          final detail = await rentalRepo.rentalDetailOfflineFirst(id);
          final header =
              Map<String, dynamic>.from(detail['rental'] as Map);
          final items = ((detail['items'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final billing = ((detail['billing_periods'] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final summaries = <String>[];
          double rentalRemaining = 0;
          var rentalActiveItems = 0;

          for (final item in items) {
            final initial =
                (item['initial_quantity'] as num?)?.toDouble() ?? 0;
            final returned =
                (item['returned_quantity'] as num?)?.toDouble() ?? 0;
            final remaining =
                (initial - returned).clamp(0.0, double.infinity).toDouble();

            if (remaining <= 0) continue;
            rentalRemaining += remaining;
            rentalActiveItems++;
            summaries.add(
              '${item['product_name']}: ${_number(remaining)} ${_unit(item['unit'])}',
            );
          }

          for (final period in billing) {
            final billed =
                (period['billed_amount'] as num?)?.toDouble() ?? 0;
            final paid =
                (period['paid_amount'] as num?)?.toDouble() ?? 0;
            nextOpenBalance +=
                (billed - paid).clamp(0.0, double.infinity).toDouble();
          }

          final active = header['status']?.toString() == 'active';
          if (active) {
            nextActiveRentalCount++;
            nextActiveItemCount += rentalActiveItems;
            nextRemaining += rentalRemaining;
          }

          cards.add(
            _CustomerRentalCardData(
              id: id,
              active: active,
              addressLabel: header['address_label']?.toString(),
              outboundDate:
                  DateTime.parse(header['original_outbound_date'].toString()),
              summaries: summaries,
              remainingTotal: rentalRemaining,
            ),
          );
        } catch (_) {
          // Bir kiralama detayı bozuksa diğer kartları göstermeye devam et.
        }
      }

      cards.sort((a, b) => b.outboundDate.compareTo(a.outboundDate));

      if (!mounted) return;
      setState(() {
        rentals = cards;
        activeRentalCount = nextActiveRentalCount;
        activeItemCount = nextActiveItemCount;
        totalRemaining = nextRemaining;
        openBalance = nextOpenBalance;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _downloadStatement() async {
    DateTimeRange? selectedRange;

    final mode = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Müşteri Hesap Ekstresi'),
        content: const Text(
          'Tüm hareketleri mi, belirli bir dönemi mi almak istiyorsun?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('Tüm Dönem'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'range'),
            child: const Text('Dönem Seç'),
          ),
        ],
      ),
    );

    if (mode == null) return;

    if (mode == 'range') {
      selectedRange = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (selectedRange == null) return;
    }

    try {
      final path = await reports.downloadCustomerStatement(
        customerId: widget.customer.id,
        customerName: widget.customer.name,
        fromDate: selectedRange?.start,
        toDate: selectedRange?.end,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Müşteri Ekstresi Hazır'),
          content: SelectableText(path),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ekstre oluşturulamadı: $e')),
      );
    }
  }

  Future<void> _newRental() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RentalCreateScreen(
          customer: widget.customer,
        ),
      ),
    );
    await _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final activeRentals = rentals.where((r) => r.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          customer.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: SifaBrand.gold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: SifaBrand.charcoal,
                    padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: SifaBrand.gold.withOpacity(0.45),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const SifaBuildingMark(size: 33),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Müşteri genel görünümü',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(
                          label: activeRentalCount > 0 ? 'Aktif' : 'Pasif',
                          tone: activeRentalCount > 0
                              ? AppStatusTone.success
                              : AppStatusTone.neutral,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _CustomerMetric(
                                label: 'Aktif Kiralama',
                                value: '$activeRentalCount',
                                icon: Icons.event_repeat_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CustomerMetric(
                                label: 'Kiradaki Kalem',
                                value: '$activeItemCount',
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CustomerMetric(
                                label: 'Toplam Kalan',
                                value: _number(totalRemaining),
                                icon: Icons.warehouse_outlined,
                                emphasize: true,
                              ),
                            ),
                          ],
                        ),
                        if (isAdmin) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: openBalance > 0
                                  ? const Color(0xFFFFF4E5)
                                  : SifaBrand.ivory,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: openBalance > 0
                                    ? const Color(0xFFF1D8AF)
                                    : SifaBrand.softGrey,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: SifaBrand.deepGold,
                                ),
                                const SizedBox(width: 9),
                                const Expanded(
                                  child: Text(
                                    'Açık Hesap',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  '${_money(openBalance)} ₺',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: openBalance > 0
                                            ? const Color(0xFF9A5D00)
                                            : SifaBrand.charcoal,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text('Güncelleme hatası: $error'),
            ],
            if (canWrite) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _newRental,
                icon: const Icon(Icons.add_business_outlined),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('YENİ KİRALAMA'),
                ),
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Aktif Kiralamalar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                StatusPill(
                  label: '${activeRentals.length}',
                  tone: AppStatusTone.neutral,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!loading && activeRentals.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined, size: 34),
                      SizedBox(height: 8),
                      Text(
                        'Aktif kiralama yok',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...activeRentals.map(
                (rental) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RentalTrackingDetailScreen(
                              recordId: rental.id,
                            ),
                          ),
                        );
                        await _loadSummary();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    rental.addressLabel ?? 'Şantiye seçilmedi',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const StatusPill(
                                  label: 'Aktif',
                                  tone: AppStatusTone.success,
                                  compact: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'İlk çıkış: ${trDate(rental.outboundDate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            if (rental.summaries.isEmpty)
                              const Text('Müşteride kalan malzeme görünmüyor.')
                            else
                              ...rental.summaries.take(4).map(
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
                            if (rental.summaries.length > 4)
                              Text(
                                '+${rental.summaries.length - 4} kalem daha',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'Toplam kalan: ${_number(rental.remainingTotal)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Diğer İşlemler',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sell_outlined),
                    title: const Text(
                      'Satılanlar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SalesScreen(
                            customerId: customer.id,
                            customerName: customer.name,
                          ),
                        ),
                      );
                    },
                  ),
                  if (isAdmin) ...[
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.assessment_outlined),
                      title: const Text(
                        'Müşteri Hesap Ekstresi',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        'Kiralama, fatura, tahsilat ve bakiye raporu',
                      ),
                      trailing: const Icon(Icons.download_outlined),
                      onTap: _downloadStatement,
                    ),
                  ],
                ],
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

  static String _unit(dynamic unit) => switch (unit?.toString()) {
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

class _CustomerMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasize;

  const _CustomerMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: emphasize ? SifaBrand.goldBg : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: emphasize
              ? SifaBrand.gold.withOpacity(0.35)
              : SifaBrand.softGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: emphasize ? SifaBrand.deepGold : SifaBrand.textGrey,
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: SifaBrand.charcoal,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: SifaBrand.textGrey,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRentalCardData {
  final String id;
  final bool active;
  final String? addressLabel;
  final DateTime outboundDate;
  final List<String> summaries;
  final double remainingTotal;

  const _CustomerRentalCardData({
    required this.id,
    required this.active,
    required this.addressLabel,
    required this.outboundDate,
    required this.summaries,
    required this.remainingTotal,
  });
}
