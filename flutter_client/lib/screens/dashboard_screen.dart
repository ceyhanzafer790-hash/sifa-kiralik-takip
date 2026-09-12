import 'package:flutter/material.dart';

import '../services/dashboard_api_repository.dart';
import '../services/rental_date_service.dart';
import '../services/role_service.dart';
import 'document_compliance_screen.dart';
import 'reminder_center_screen.dart';
import 'reports_screen.dart';
import 'receivables_screen.dart';
import 'overdue_receivables_screen.dart';
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Genel Durum',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (d != null)
                Chip(
                  avatar: Icon(
                    d['source'] == 'server'
                        ? Icons.cloud_done_outlined
                        : Icons.phone_android_outlined,
                    size: 18,
                  ),
                  label: Text(
                    d['source'] == 'server'
                        ? 'Merkez'
                        : 'Offline veri',
                  ),
                ),
            ],
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Güncelleme hatası: $error'),
            ),
          const SizedBox(height: 14),
          if (d != null) ...[
            _section(context, 'Bugün ve Yaklaşanlar'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatCard(
                  title: 'Bugün kira',
                  value: _count(d['renewal_due_today_count']),
                  icon: Icons.event_repeat_outlined,
                  onTap: () => _open(
                    const ReminderCenterScreen(),
                  ),
                ),
                _StatCard(
                  title: '3 gün içinde',
                  value: _count(d['renewal_next_3_days_count']),
                  icon: Icons.upcoming_outlined,
                  onTap: () => _open(
                    const ReminderCenterScreen(),
                  ),
                ),
                _StatCard(
                  title: 'Fatura bekliyor',
                  value: _count(d['invoice_reminder_count']),
                  icon: Icons.receipt_long_outlined,
                  onTap: () => _open(
                    const ReminderCenterScreen(),
                  ),
                ),
                _StatCard(
                  title: 'Eksik belge',
                  value: _count(d['missing_document_count']),
                  subtitle:
                      '${_count(d['missing_document_rental_count'])} kiralama',
                  icon: Icons.description_outlined,
                  onTap: d['source'] == 'server'
                      ? () => _open(
                            const DocumentComplianceScreen(),
                          )
                      : null,
                ),
              ],
            ),
            if (canSeeFinancials &&
                d['financials_visible'] != false) ...[
              const SizedBox(height: 20),
              _section(context, 'Finansal Görünüm'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MoneyCard(
                    title: 'Tahmini aylık kira',
                    amount: _double(
                      d['estimated_monthly_rental_revenue'],
                    ),
                    subtitle:
                        '${_count(d['estimated_revenue_unpriced_item_count'])} fiyatı eksik kalem',
                    icon: Icons.trending_up_outlined,
                    footnote: 'Tahmindir, fatura değildir.',
                    onTap: d['source'] == 'server'
                        ? () => _open(
                              const RevenueBreakdownScreen(),
                            )
                        : null,
                  ),
                  _MoneyCard(
                    title: 'Kesilmiş fatura alacağı',
                    amount: _double(
                      d['issued_receivable_balance'],
                    ),
                    subtitle:
                        '${_count(d['issued_receivable_count'])} açık dönem',
                    icon: Icons.account_balance_wallet_outlined,
                    footnote:
                        'Kesilmiş faturaların kalan bakiyesi.',
                    onTap: d['source'] == 'server'
                        ? () => _open(
                              const ReceivablesScreen(),
                            )
                        : null,
                  ),
                  _MoneyCard(
                    title: 'Vadesi geçmiş alacak',
                    amount: _double(
                      d['overdue_receivable_balance'],
                    ),
                    subtitle:
                        '${_count(d['overdue_receivable_count'])} dönem • '
                        '${_count(d['open_invoice_missing_due_date_count'])} faturada vade yok',
                    icon: Icons.warning_amber_outlined,
                    footnote:
                        'Yalnız ödeme vadesi girilmiş faturalar üzerinden.',
                    onTap: d['source'] == 'server'
                        ? () => _open(
                              const OverdueReceivablesScreen(),
                            )
                        : null,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _section(context, 'Kayıt Sağlığı'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatCard(
                  title: 'Müşteri',
                  value: _count(d['customer_count']),
                  icon: Icons.people_outline,
                ),
                _StatCard(
                  title: 'Stok güveni bilinmiyor',
                  value: _count(d['unknown_stock_product_count']),
                  icon: Icons.inventory_2_outlined,
                ),
                _StatCard(
                  title: 'Eski veri bekliyor',
                  value: _count(d['legacy_import_pending']),
                  subtitle: d['legacy_import_pending'] == null
                      ? 'Merkez bağlantısında görünür'
                      : null,
                  icon: Icons.rule_folder_outlined,
                ),
                _StatCard(
                  title: 'Raporlar',
                  value: 'Excel / CSV',
                  icon: Icons.assessment_outlined,
                  onTap: () => _open(const ReportsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _section(context, 'Yaklaşan Kira Yenilemeleri'),
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
              ...renewals.take(15).map(
                (r) {
                  final invoiceRequired =
                      r['invoice_preference'] == 'invoice_required';
                  final invoiceIssued =
                      r['invoice_status'] == 'issued';
                  final daysUntil =
                      (r['days_until'] as num?)?.toInt() ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          invoiceRequired && !invoiceIssued
                              ? Icons.receipt_long_outlined
                              : Icons.event_repeat_outlined,
                        ),
                        title: Text(
                          '${r['customer_name']} • '
                          '${_displayDate(r['renewal_date'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (r['address_label'] != null)
                              r['address_label'].toString(),
                            daysUntil == 0
                                ? 'Kira yenilemesi bugün'
                                : '$daysUntil gün kaldı',
                            if (invoiceRequired && !invoiceIssued)
                              'FATURA KESİLECEK',
                          ].join(' • '),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      );

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String _count(dynamic value) {
    if (value == null) return '-';
    return (value as num).toInt().toString();
  }

  double _double(dynamic value) =>
      (value as num?)?.toDouble() ?? 0;

  String _displayDate(dynamic raw) {
    final d = DateTime.tryParse(raw.toString());
    return d == null ? raw.toString() : trDate(d);
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 185,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(height: 10),
                Text(title),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyCard extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;
  final String footnote;
  final IconData icon;
  final VoidCallback? onTap;

  const _MoneyCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.footnote,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 10),
              Text(title),
              const SizedBox(height: 5),
              Text(
                '${_money(amount)} ₺',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(subtitle),
              const SizedBox(height: 8),
              Text(
                footnote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              ],
            ),
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
    return parts[1] == '00'
        ? whole
        : '$whole,${parts[1]}';
  }
}
