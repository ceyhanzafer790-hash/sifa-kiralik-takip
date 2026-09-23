import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/dashboard_api_repository.dart';
import '../services/rental_date_service.dart';
import '../services/role_service.dart';
import '../widgets/sifa_brand.dart';
import 'global_search_screen.dart';
import 'customer_list_screen.dart';
import 'overdue_receivables_screen.dart';
import 'receivables_screen.dart';
import 'reminder_center_screen.dart';
import 'rentals_overview_screen.dart';
import 'revenue_breakdown_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final repo = DashboardApiRepository();
  final roles = RoleService();

  Map<String, dynamic>? data;
  bool canSeeFinancials = false;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await Future.wait([
        repo.summary(
          today: DateTime.now(),
          days: 30,
        ),
        roles.canSeeFinancials(),
      ]);

      if (mounted) {
        setState(() {
          data = result[0] as Map<String, dynamic>;
          canSeeFinancials = result[1] as bool;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final renewals = ((d?['renewals'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final recentMovements =
        ((d?['recent_movements'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = math.min(
      230.0,
      math.max(155.0, (screenWidth - 42) / 2),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merhaba',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Bugün de sağlam adımlar atalım.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: SifaBrand.textGrey,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _displayDate(DateTime.now().toIso8601String()),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (d != null)
                    Text(
                      d['source'] == 'server' ? 'Merkez veri' : 'Offline veri',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: SifaBrand.textGrey,
                          ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _open(const GlobalSearchScreen()),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Müşteri, şantiye, malzeme veya kiralama ara',
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Güncelleme hatası: $error'),
            ),
          if (d != null) ...[
            const SizedBox(height: 18),
            Text(
              'Genel Durum',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricCard(
                  width: cardWidth,
                  title: 'Aktif Müşteri',
                  value: _count(d['customer_count']),
                  subtitle: 'Kayıtlı müşteri',
                  icon: Icons.people_alt_outlined,
                  onTap: () => _open(const CustomerListScreen()),
                ),
                _MetricCard(
                  width: cardWidth,
                  title: 'Aktif Kiralama',
                  value: _count(d['active_rental_count']),
                  subtitle: 'Devam eden kiralama',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => _open(const RentalsOverviewScreen()),
                ),
                _MetricCard(
                  width: cardWidth,
                  title: 'Müşteride',
                  value: _count(d['active_rental_item_count']),
                  subtitle: 'Aktif malzeme kalemi',
                  icon: Icons.apartment_outlined,
                  onTap: () => _open(const RentalsOverviewScreen()),
                ),
                _MetricCard(
                  width: cardWidth,
                  title: 'Bugünkü Hareket',
                  value: _count(d['today_movement_count']),
                  subtitle: 'Giden + gelen',
                  icon: Icons.arrow_forward_rounded,
                  onTap: () => _open(const RentalsOverviewScreen()),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const SifaSectionTitle(
              title: 'Son Hareketler',
            ),
            const SizedBox(height: 8),
            if (recentMovements.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz malzeme hareketi görünmüyor.'),
                ),
              )
            else
              ...recentMovements.map((movement) {
                final outbound =
                    movement['movement_type']?.toString() == 'outbound';
                final date = DateTime.tryParse(
                  movement['movement_date']?.toString() ?? '',
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Card(
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: outbound
                              ? SifaBrand.gold.withOpacity(0.12)
                              : SifaBrand.successBg,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: SifaBuildingMark(
                          size: 28,
                          gold: outbound,
                        ),
                      ),
                      title: Text(
                        movement['customer_name']?.toString() ?? 'Müşteri',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (date != null) _displayDate(date.toIso8601String()),
                          '${_number(_double(movement['quantity']))} '
                              '${_unit(movement['unit'])} '
                              '${movement['product_name'] ?? 'Malzeme'} '
                              '${outbound ? 'çıktı' : 'geri geldi'}',
                        ].join('\n'),
                      ),
                      trailing: Icon(
                        outbound ? Icons.north_east : Icons.south_west,
                        color: outbound
                            ? SifaBrand.deepGold
                            : SifaBrand.success,
                      ),
                      isThreeLine: true,
                    ),
                  ),
                );
              }),
            if (canSeeFinancials && d['financials_visible'] != false) ...[
              const SizedBox(height: 22),
              Text(
                'Para Durumu',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              _FinancialCard(
                title: 'Tahmini aylık kira',
                amount: _double(d['estimated_monthly_rental_revenue']),
                subtitle:
                    '${_count(d['estimated_revenue_unpriced_item_count'])} fiyatı eksik kalem',
                icon: Icons.trending_up,
                onTap: d['source'] == 'server'
                    ? () => _open(const RevenueBreakdownScreen())
                    : null,
              ),
              const SizedBox(height: 8),
              _FinancialCard(
                title: 'Açık alacak',
                amount: _double(d['issued_receivable_balance']),
                subtitle:
                    '${_count(d['issued_receivable_count'])} açık dönem',
                icon: Icons.account_balance_wallet_outlined,
                onTap: d['source'] == 'server'
                    ? () => _open(const ReceivablesScreen())
                    : null,
              ),
              if (_double(d['overdue_receivable_balance']) > 0) ...[
                const SizedBox(height: 8),
                _FinancialCard(
                  title: 'Vadesi geçmiş',
                  amount: _double(d['overdue_receivable_balance']),
                  subtitle:
                      '${_count(d['overdue_receivable_count'])} geciken dönem',
                  icon: Icons.warning_amber_rounded,
                  onTap: d['source'] == 'server'
                      ? () => _open(const OverdueReceivablesScreen())
                      : null,
                ),
              ],
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Yaklaşan Kiralar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => _open(const ReminderCenterScreen()),
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (renewals.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Önümüzdeki 30 günde yenileme görünmüyor.',
                  ),
                ),
              )
            else
              ...renewals.take(6).map(
                (r) {
                  final invoiceRequired =
                      r['invoice_preference'] == 'invoice_required';
                  final invoiceIssued = r['invoice_status'] == 'issued';
                  final daysUntil = (r['days_until'] as num?)?.toInt() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            invoiceRequired && !invoiceIssued
                                ? Icons.receipt_long_outlined
                                : Icons.event_repeat_outlined,
                          ),
                        ),
                        title: Text(
                          r['customer_name']?.toString() ?? 'Müşteri',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (r['address_label'] != null)
                              r['address_label'].toString(),
                            _displayDate(r['renewal_date']),
                            daysUntil == 0
                                ? 'Bugün'
                                : '$daysUntil gün kaldı',
                            if (invoiceRequired && !invoiceIssued)
                              'Fatura bekliyor',
                          ].join(' • '),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String _count(dynamic value) {
    if (value == null) return '-';
    return (value as num).toInt().toString();
  }

  double _double(dynamic value) => (value as num?)?.toDouble() ?? 0;

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

  String _unit(dynamic unit) => switch (unit?.toString()) {
        'sheet' => 'Levha',
        'meter' => 'Metre',
        'squareMeter' || 'square_meter' => 'm²',
        'cubicMeter' || 'cubic_meter' => 'm³',
        'kilogram' => 'kg',
        'liter' => 'Litre',
        'set' => 'Takım',
        _ => 'Adet',
      };

  String _displayDate(dynamic raw) {
    final d = DateTime.tryParse(raw.toString());
    return d == null ? raw.toString() : trDate(d);
  }

}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SifaBrand.gold.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: SifaBrand.deepGold, size: 21),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _FinancialCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 2),
                    Text(
                      '${_money(amount)} ₺',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final reversed = parts[0].split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < reversed.length; i += 3) {
      groups.add(
        reversed.skip(i).take(3).toList().reversed.join(),
      );
    }

    final whole = groups.reversed.join('.');
    return parts[1] == '00' ? whole : '$whole,${parts[1]}';
  }
}
), '')
          .replaceFirst(RegExp(r'\.
    final d = DateTime.tryParse(raw.toString());
    return d == null ? raw.toString() : trDate(d);
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SifaBrand.gold.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: SifaBrand.deepGold, size: 21),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _FinancialCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 2),
                    Text(
                      '${_money(amount)} ₺',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final reversed = parts[0].split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < reversed.length; i += 3) {
      groups.add(
        reversed.skip(i).take(3).toList().reversed.join(),
      );
    }

    final whole = groups.reversed.join('.');
    return parts[1] == '00' ? whole : '$whole,${parts[1]}';
  }
}
), '');

  String _unit(dynamic unit) => switch (unit?.toString()) {
        'sheet' => 'Levha',
        'meter' => 'Metre',
        'squareMeter' || 'square_meter' => 'm²',
        'cubicMeter' || 'cubic_meter' => 'm³',
        'kilogram' => 'kg',
        'liter' => 'Litre',
        'set' => 'Takım',
        _ => 'Adet',
      };

  String _displayDate(dynamic raw) {
    final d = DateTime.tryParse(raw.toString());
    return d == null ? raw.toString() : trDate(d);
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SifaBrand.gold.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: SifaBrand.deepGold, size: 21),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _FinancialCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(child: Icon(icon)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title),
                    const SizedBox(height: 2),
                    Text(
                      '${_money(amount)} ₺',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  static String _money(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final reversed = parts[0].split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < reversed.length; i += 3) {
      groups.add(
        reversed.skip(i).take(3).toList().reversed.join(),
      );
    }

    final whole = groups.reversed.join('.');
    return parts[1] == '00' ? whole : '$whole,${parts[1]}';
  }
}
