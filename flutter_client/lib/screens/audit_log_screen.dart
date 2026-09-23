import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/admin_api_repository.dart';
import '../services/customer_api_repository.dart';
import 'customer_detail_screen.dart';
import 'rental_tracking_detail_screen.dart';
import '../services/report_download_service.dart';
import '../widgets/sifa_brand.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final repo = AdminApiRepository();
  final customersRepo = CustomerApiRepository();
  final reports = ReportDownloadService();
  final searchController = TextEditingController();

  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> users = [];
  List<String> entityTypes = [];
  List<String> actions = [];

  String? selectedUserId;
  String? selectedEntityType;
  String? selectedAction;
  DateTimeRange? dateRange;

  int total = 0;
  int offset = 0;
  static const pageSize = 100;

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final facets = await repo.auditFacets();
      users = ((facets['users'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      entityTypes = ((facets['entity_types'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      actions = ((facets['actions'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      // Ana liste yine yüklenebilir.
    }
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) offset = 0;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final end = dateRange == null
          ? null
          : DateTime(
              dateRange!.end.year,
              dateRange!.end.month,
              dateRange!.end.day,
              23,
              59,
              59,
              999,
            );

      final result = await repo.audit(
        limit: pageSize,
        offset: offset,
        userId: selectedUserId,
        entityType: selectedEntityType,
        action: selectedAction,
        query: searchController.text,
        fromAt: dateRange?.start,
        toAt: end,
      );

      if (!mounted) return;

      setState(() {
        total = (result['total'] as num?)?.toInt() ?? 0;
        rows = ((result['items'] as List?) ?? const [])
            .map(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> _export(String format) async {
    final end = dateRange == null
        ? null
        : DateTime(
            dateRange!.end.year,
            dateRange!.end.month,
            dateRange!.end.day,
            23,
            59,
            59,
            999,
          );

    try {
      final path = await reports.download(
        reportType: 'audit',
        format: format,
        filters: {
          'user_id': selectedUserId,
          'entity_type': selectedEntityType,
          'action': selectedAction,
          'q': searchController.text,
          'from_at': dateRange?.start.toIso8601String(),
          'to_at': end?.toIso8601String(),
        },
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('İşlem Geçmişi Raporu Hazır'),
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
        SnackBar(content: Text('Rapor oluşturulamadı: $e')),
      );
    }
  }

  Future<void> _chooseDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dateRange,
    );

    if (range == null) return;
    setState(() => dateRange = range);
    await _load(reset: true);
  }

  void _clear() {
    setState(() {
      selectedUserId = null;
      selectedEntityType = null;
      selectedAction = null;
      dateRange = null;
      searchController.clear();
      offset = 0;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final pageStart = total == 0 ? 0 : offset + 1;
    final pageEnd = (offset + rows.length).clamp(0, total);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'İşlem Geçmişi',
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
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Container(
                color: SifaBrand.charcoal,
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                child: const Row(
                  children: [
                    Icon(
                      Icons.history_outlined,
                      color: SifaBrand.gold,
                      size: 27,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Denetim Kayıtları',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Kullanıcı, kayıt türü, işlem ve tarihe göre hareketleri incele.',
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
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Ara',
                hintText:
                    'Müşteri, kullanıcı, işlem, kayıt ID veya payload…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () => _load(reset: true),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
              onSubmitted: (_) => _load(reset: true),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DropdownButton<String?>(
                  value: selectedUserId,
                  hint: const Text('Kullanıcı'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tüm kullanıcılar'),
                    ),
                    ...users.map(
                      (u) => DropdownMenuItem<String?>(
                        value: u['id'].toString(),
                        child: Text(
                          u['full_name']?.toString() ??
                              u['email']?.toString() ??
                              'Kullanıcı',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedUserId = value);
                    _load(reset: true);
                  },
                ),
                DropdownButton<String?>(
                  value: selectedEntityType,
                  hint: const Text('Kayıt Türü'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tüm kayıt türleri'),
                    ),
                    ...entityTypes.map(
                      (v) => DropdownMenuItem<String?>(
                        value: v,
                        child: Text(_entityLabel(v)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedEntityType = value);
                    _load(reset: true);
                  },
                ),
                DropdownButton<String?>(
                  value: selectedAction,
                  hint: const Text('İşlem'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tüm işlemler'),
                    ),
                    ...actions.map(
                      (v) => DropdownMenuItem<String?>(
                        value: v,
                        child: Text(_actionLabel(v)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => selectedAction = value);
                    _load(reset: true);
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _chooseDates,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    dateRange == null
                        ? 'Tarih'
                        : '${_shortDate(dateRange!.start)} - '
                          '${_shortDate(dateRange!.end)}',
                  ),
                ),
                TextButton(
                  onPressed: _clear,
                  child: const Text('Filtreleri Temizle'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Dışa Aktar',
                  onSelected: _export,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'xlsx',
                      child: Text('Excel olarak dışa aktar'),
                    ),
                    PopupMenuItem(
                      value: 'csv',
                      child: Text('CSV olarak dışa aktar'),
                    ),
                  ],
                  child: const Chip(
                    avatar: Icon(Icons.download_outlined),
                    label: Text('Dışa Aktar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$total kayıt • $pageStart-$pageEnd gösteriliyor',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(error!),
                ),
              ),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      '${row['user_name'] ?? 'Sistem'} • '
                      '${_actionLabel(row['action']?.toString() ?? '')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${_entityLabel(row['entity_type']?.toString() ?? '')}'
                      ' • ${_dateTime(row['created_at'])}\n'
                      'Kayıt: ${row['entity_id']}',
                    ),
                    isThreeLine: true,
                    onTap: () => _detail(row),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: offset > 0 && !loading
                      ? () {
                          setState(
                            () => offset =
                                (offset - pageSize).clamp(0, total),
                          );
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Önceki'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: offset + rows.length < total && !loading
                      ? () {
                          setState(() => offset += pageSize);
                          _load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Sonraki'),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }


Future<void> _openRelatedRecord(
  Map<String, dynamic> navigation,
) async {
  final target = navigation['target']?.toString();

  if (target == 'rental') {
    final rentalId =
        navigation['rental_record_id']?.toString();

    if (rentalId == null || rentalId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RentalTrackingDetailScreen(
          recordId: rentalId,
        ),
      ),
    );
    return;
  }

  if (target == 'customer') {
    final customerId =
        navigation['customer_id']?.toString();

    if (customerId == null || customerId.isEmpty) return;

    final row = await customersRepo.getByIdOfflineFirst(
      customerId,
    );

    if (!mounted || row == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          customer: Customer(
            id: row['id'].toString(),
            name: row['name'].toString(),
          ),
        ),
      ),
    );
  }
}

  Future<void> _detail(Map<String, dynamic> row) async {
    const encoder = JsonEncoder.withIndent('  ');
    final payload = encoder.convert(row['payload'] ?? {});

    Map<String, dynamic>? navigation;

    try {
      navigation = await repo.auditNavigation(
        row['id'].toString(),
      );
    } catch (_) {
      navigation = null;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('İşlem Detayı'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: SelectableText(
              'Kullanıcı: ${row['user_name'] ?? 'Sistem'}\n'
              'E-posta: ${row['user_email'] ?? '-'}\n'
              'Kayıt türü: ${row['entity_type']}\n'
              'Kayıt ID: ${row['entity_id']}\n'
              'İşlem: ${row['action']}\n'
              'Tarih: ${row['created_at']}\n\n'
              '$payload',
            ),
          ),
        ),
        actions: [
          if (navigation != null &&
              navigation['target'] != 'none')
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openRelatedRecord(navigation!);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('İlgili Kayda Git'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String _actionLabel(String action) => switch (action) {
        'created' => 'Oluşturdu',
        'updated' => 'Güncelledi',
        'deactivated' => 'Pasifleştirdi',
        'return_added' => 'İade ekledi',
        'rate_added' => 'Fiyat ekledi/değiştirdi',
        'document_uploaded' => 'Belge yükledi',
        'write_off' => 'Hurda/kayıp hareketi yaptı',
        'repair_completed' => 'Tamiri tamamladı',
        'password_reset' => 'Şifre yeniledi',
        'role_changed' => 'Rol değiştirdi',
        'address_added' => 'Adres/şantiye ekledi',
        _ => action,
      };

  String _entityLabel(String type) => switch (type) {
        'customer' => 'Müşteri',
        'rental_record' => 'Kiralama Takibi',
        'rental_rate' => 'Kira Fiyatı',
        'rental_document' => 'Belge',
        'app_user' => 'Kullanıcı',
        'app_runtime_settings' => 'Sistem Ayarı',
        'app_release' => 'Sürüm Paketi',
        'document_compliance_exception' => 'Belge İstisnası',
        _ => type,
      };

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _dateTime(dynamic raw) {
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return raw.toString();
    return '${_shortDate(d)} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
