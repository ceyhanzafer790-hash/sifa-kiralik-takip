import 'package:flutter/material.dart';

import '../services/customer_api_repository.dart';
import '../services/report_download_service.dart';
import '../services/role_service.dart';
import '../widgets/sifa_brand.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final reports = ReportDownloadService();
  final customersRepo = CustomerApiRepository();
  final roles = RoleService();

  String? busy;
  bool isAdmin = false;
  String? customerId;
  String? customerName;
  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final value = await roles.isAdmin();
    if (mounted) setState(() => isAdmin = value);
  }

  Future<void> _download(
    String type,
    String format, {
    Map<String, String?> extra = const {},
  }) async {
    final key = '$type:$format';
    setState(() => busy = key);

    try {
      final path = await reports.download(
        reportType: type,
        format: format,
        filters: {
          'customer_id': customerId,
          'from_date': _dateOrNull(fromDate),
          'to_date': _dateOrNull(toDate),
          ...extra,
        },
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Rapor Hazır'),
          content: SelectableText('Dosya kaydedildi:\n\n$path'),
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
        SnackBar(content: Text('Rapor oluşturulamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> _chooseCustomer() async {
    List<Map<String, dynamic>> customers = [];
    try {
      customers = await customersRepo.list();
    } catch (_) {
      // Raporlar merkez sunucu gerektirir; hata indirmede zaten görünür.
    }

    if (!mounted) return;

    final selected = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Müşteri Filtresi'),
        children: [
          ListTile(
            title: const Text('Tüm müşteriler'),
            onTap: () => Navigator.pop(context, <String, dynamic>{}),
          ),
          ...customers.map(
            (c) => ListTile(
              title: Text(c['name'].toString()),
              onTap: () => Navigator.pop(context, c),
            ),
          ),
        ],
      ),
    );

    if (selected == null) return;

    setState(() {
      customerId = selected['id']?.toString();
      customerName = selected['name']?.toString();
    });
  }

  Future<void> _chooseRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: fromDate != null && toDate != null
          ? DateTimeRange(start: fromDate!, end: toDate!)
          : null,
    );

    if (range == null) return;
    setState(() {
      fromDate = range.start;
      toDate = range.end;
    });
  }

  void _clearFilters() {
    setState(() {
      customerId = null;
      customerName = null;
      fromDate = null;
      toDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filterText = [
      if (customerName != null) customerName!,
      if (fromDate != null && toDate != null)
        '${_display(fromDate!)} - ${_display(toDate!)}',
    ].join(' • ');

    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rapor Filtresi',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    filterText.isEmpty
                        ? 'Tüm kayıtlar'
                        : filterText,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _chooseCustomer,
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Müşteri'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _chooseRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: const Text('Tarih'),
                      ),
                      if (filterText.isNotEmpty)
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Filtreyi Temizle'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ReportCard(
            title: 'Kiralama Takibi',
            subtitle:
                'Müşteri, şantiye, gönderilen, iade, kalan ve güncel fiyat.',
            icon: Icons.event_repeat_outlined,
            onXlsx: () => _download(
              'rentals',
              'xlsx',
              extra: {'status': 'active'},
            ),
            onCsv: () => _download(
              'rentals',
              'csv',
              extra: {'status': 'active'},
            ),
            xlsxBusy: busy == 'rentals:xlsx',
            csvBusy: busy == 'rentals:csv',
          ),
          _ReportCard(
            title: 'Stok Özeti',
            subtitle:
                'Kullanılabilir, tamirlik, hurda, kayıp ve stok güven seviyesi.',
            icon: Icons.inventory_2_outlined,
            onXlsx: () => _download('stock', 'xlsx'),
            onCsv: () => _download('stock', 'csv'),
            xlsxBusy: busy == 'stock:xlsx',
            csvBusy: busy == 'stock:csv',
          ),
          if (isAdmin)
            _ReportCard(
            title: 'Fatura ve Tahsilat',
            subtitle:
                'Kira dönemi, fatura durumu, tahsil edilen ve kalan bakiye.',
            icon: Icons.receipt_long_outlined,
            onXlsx: () => _download('billing', 'xlsx'),
            onCsv: () => _download('billing', 'csv'),
            xlsxBusy: busy == 'billing:xlsx',
            csvBusy: busy == 'billing:csv',
          ),
        ],
      ),
    );
  }

  String? _dateOrNull(DateTime? d) => d == null ? null : _date(d);

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _display(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onXlsx;
  final VoidCallback onCsv;
  final bool xlsxBusy;
  final bool csvBusy;

  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onXlsx,
    required this.onCsv,
    required this.xlsxBusy,
    required this.csvBusy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: SifaBrand.gold.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: SifaBrand.deepGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: xlsxBusy ? null : onXlsx,
                          icon: const Icon(Icons.table_view_outlined),
                          label: Text(
                            xlsxBusy ? 'Hazırlanıyor…' : 'Excel',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: csvBusy ? null : onCsv,
                          icon: const Icon(Icons.text_snippet_outlined),
                          label: Text(
                            csvBusy ? 'Hazırlanıyor…' : 'CSV',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
