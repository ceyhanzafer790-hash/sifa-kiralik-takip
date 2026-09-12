import 'package:flutter/material.dart';

import '../database/local_database.dart';
import '../services/reminder_planner.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Hatırlatmalar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Kira yenilemesi ve fatura uyarıları cihazda da hesaplanır. '
                  'İnternet kesilse bile bu liste kaybolmaz. '
                  'V0.24 test sürümünde hatırlatmalar uygulama içindedir; '
                  'uygulama kapalıyken Android/iPhone/Windows sistem bildirimi '
                  'henüz gönderilmez.',
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (loading) const LinearProgressIndicator(),
            if (!loading && rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aktif hatırlatma yok.'),
                ),
              ),
            ...rows.map(
              (row) {
                final overdue = row.dueAt.isBefore(now);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        row.reminderType == 'invoice_due'
                            ? Icons.receipt_long_outlined
                            : Icons.event_repeat_outlined,
                      ),
                      title: Text(
                        row.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        '${row.body}\n'
                        '${_display(row.dueAt)}'
                        '${overdue ? " • Süresi geldi/geçti" : ""}',
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RentalTrackingDetailScreen(
                            recordId: row.rentalId,
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Tamamlandı',
                        onPressed: () => _done(row),
                        icon: const Icon(Icons.done),
                      ),
                    ),
                  ),
                );
              },
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
