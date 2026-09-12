import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/role_service.dart';
import '../services/report_download_service.dart';
import 'rental_create_screen.dart';
import 'rental_section_screen.dart';
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
  bool canWrite = false;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final result = await Future.wait([
      roles.canWrite(),
      roles.isAdmin(),
    ]);
    if (mounted) {
      setState(() {
        canWrite = result[0];
        isAdmin = result[1];
      });
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

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;

    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            customer.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 16),
          if (isAdmin) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.assessment_outlined),
                title: const Text(
                  'Müşteri Hesap Ekstresi',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Kiralamalar, fatura/tahsilat ve kalan bakiye Excel raporu.',
                ),
                trailing: const Icon(Icons.download_outlined),
                onTap: _downloadStatement,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: ListTile(
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
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: const Text(
                'Kiralananlar',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Gidenler • Gelenler • Kiralama Takibi',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RentalSectionScreen(
                      customer: customer,
                    ),
                  ),
                );
              },
            ),
          ),
          if (canWrite) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RentalCreateScreen(
                      customer: customer,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_business_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('YENİ KİRALAMA'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
