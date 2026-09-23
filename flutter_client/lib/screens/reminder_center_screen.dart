import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../services/reminder_planner.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';
import 'rental_tracking_detail_screen.dart';

class ReminderCenterScreen extends StatefulWidget {
  const ReminderCenterScreen({super.key});

  @override
  State<ReminderCenterScreen> createState() =>
      _ReminderCenterScreenState();
}

class _ReminderCenterScreenState extends State<ReminderCenterScreen> {
  final planner = ReminderPlanner();
  List<LocalReminderEvent> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    await planner.refresh();
    final result = await planner.active();
    result.sort((a, b) => a.dueAt.compareTo(b.dueAt));

    if (mounted) {
      setState(() {
        rows = result;
        loading = false;
      });
    }
  }

  Future<void> _done(LocalReminderEvent row) async {
    await planner.acknowledge(row.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdueCount =
        rows.where((row) => row.dueAt.isBefore(now)).length;
    final upcomingCount = rows.length - overdueCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hatırlatmalar',
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
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: SifaBrand.charcoal,
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          color: SifaBrand.gold,
                          size: 27,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'İş Takibi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Kira yenilemesi ve fatura uyarılarını kaçırma.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(13),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ReminderMetric(
                            label: 'Geciken',
                            value: overdueCount,
                            warning: overdueCount > 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ReminderMetric(
                            label: 'Yaklaşan',
                            value: upcomingCount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ReminderMetric(
                            label: 'Toplam',
                            value: rows.length,
                            emphasize: rows.isNotEmpty,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 14),
            if (!loading && rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 38,
                        color: SifaBrand.success,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Aktif hatırlatma yok.',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...rows.map((row) {
                final overdue = row.dueAt.isBefore(now);
                final invoice = row.reminderType == 'invoice_due';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RentalTrackingDetailScreen(
                            recordId: row.rentalId,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: overdue
                                    ? const Color(0xFFFFECEC)
                                    : invoice
                                        ? SifaBrand.goldBg
                                        : SifaBrand.infoBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                invoice
                                    ? Icons.receipt_long_outlined
                                    : Icons.event_repeat_outlined,
                                color: overdue
                                    ? const Color(0xFFA53C3C)
                                    : invoice
                                        ? SifaBrand.deepGold
                                        : SifaBrand.info,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          row.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15.5,
                                          ),
                                        ),
                                      ),
                                      StatusPill(
                                        label:
                                            overdue ? 'Gecikti' : 'Yaklaşıyor',
                                        tone: overdue
                                            ? AppStatusTone.danger
                                            : AppStatusTone.info,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(row.body),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 15,
                                        color: overdue
                                            ? const Color(0xFFA53C3C)
                                            : SifaBrand.textGrey,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _display(row.dueAt),
                                        style: TextStyle(
                                          color: overdue
                                              ? const Color(0xFFA53C3C)
                                              : SifaBrand.textGrey,
                                          fontWeight: overdue
                                              ? FontWeight.w900
                                              : FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Tamamlandı',
                              onPressed: () => _done(row),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                color: SifaBrand.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: SifaBrand.ivory,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SifaBrand.softGrey),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.phone_android_outlined,
                    size: 18,
                    color: SifaBrand.deepGold,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hatırlatmalar uygulama içinde ve offline çalışır. '
                      'Uygulama tamamen kapalıyken işletim sistemi bildirimi henüz gönderilmez.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _display(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

class _ReminderMetric extends StatelessWidget {
  final String label;
  final int value;
  final bool warning;
  final bool emphasize;

  const _ReminderMetric({
    required this.label,
    required this.value,
    this.warning = false,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = warning
        ? const Color(0xFFA53C3C)
        : emphasize
            ? SifaBrand.deepGold
            : SifaBrand.charcoal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
      decoration: BoxDecoration(
        color: warning
            ? const Color(0xFFFFECEC)
            : emphasize
                ? SifaBrand.goldBg
                : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: foreground,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: SifaBrand.textGrey,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
