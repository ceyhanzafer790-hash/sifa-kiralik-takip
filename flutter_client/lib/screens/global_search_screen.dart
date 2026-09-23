import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/global_search_repository.dart';
import '../services/rental_date_service.dart';
import '../widgets/sifa_brand.dart';
import '../widgets/status_pill.dart';
import 'customer_detail_screen.dart';
import 'rental_tracking_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final repo = GlobalSearchRepository();
  final controller = TextEditingController();

  Map<String, dynamic>? result;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = controller.text.trim();
    if (q.isEmpty || loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await repo.search(q);
      if (mounted) setState(() => result = data);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _clear() {
    controller.clear();
    setState(() {
      result = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customers = ((result?['customers'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final rentals = ((result?['rentals'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final documents = ((result?['documents'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final total = customers.length + rentals.length + documents.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Genel Arama',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              color: SifaBrand.charcoal,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              child: const Row(
                children: [
                  Icon(
                    Icons.search,
                    color: SifaBrand.gold,
                    size: 27,
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Her Şeyi Tek Yerden Bul',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Müşteri, şantiye, malzeme, kiralama veya belge ara.',
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
          const SizedBox(height: 13),
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Aramak istediğini yaz',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Temizle',
                      onPressed: _clear,
                      icon: const Icon(Icons.clear),
                    )
                  : IconButton(
                      tooltip: 'Ara',
                      onPressed: _search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Ara'),
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Arama yapılamadı: $error',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Arama Sonuçları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                StatusPill(
                  label: '$total sonuç',
                  tone: AppStatusTone.neutral,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (total > 0)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (customers.isNotEmpty)
                    StatusPill(
                      label: '${customers.length} müşteri',
                      tone: AppStatusTone.info,
                      compact: true,
                    ),
                  if (rentals.isNotEmpty)
                    StatusPill(
                      label: '${rentals.length} kiralama',
                      tone: AppStatusTone.success,
                      compact: true,
                    ),
                  if (documents.isNotEmpty)
                    StatusPill(
                      label: '${documents.length} belge',
                      tone: AppStatusTone.warning,
                      compact: true,
                    ),
                ],
              ),
            if (customers.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(context, 'Müşteriler'),
              const SizedBox(height: 7),
              ...customers.map(
                (customer) => _ResultCard(
                  icon: Icons.business_outlined,
                  title: customer['name']?.toString() ?? 'Müşteri',
                  subtitle: customer['phone']?.toString(),
                  tone: AppStatusTone.info,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerDetailScreen(
                        customer: Customer(
                          id: customer['id'].toString(),
                          name: customer['name'].toString(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (rentals.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(context, 'Kiralamalar'),
              const SizedBox(height: 7),
              ...rentals.map((rental) {
                final date = DateTime.tryParse(
                  rental['original_outbound_date']?.toString() ?? '',
                );
                return _ResultCard(
                  icon: Icons.event_repeat_outlined,
                  title: rental['customer_name']?.toString() ?? 'Müşteri',
                  subtitle: [
                    if (rental['address_label'] != null)
                      rental['address_label'].toString(),
                    if (date != null) 'İlk çıkış ${trDate(date)}',
                  ].join(' • '),
                  tone: AppStatusTone.success,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RentalTrackingDetailScreen(
                        recordId: rental['id'].toString(),
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (documents.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(context, 'Belgeler'),
              const SizedBox(height: 7),
              ...documents.map(
                (document) => _ResultCard(
                  icon: _documentIcon(
                    document['document_type']?.toString(),
                  ),
                  title:
                      document['original_file_name']?.toString() ?? 'Belge',
                  subtitle: _documentLabel(
                    document['document_type']?.toString(),
                  ),
                  tone: AppStatusTone.warning,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RentalTrackingDetailScreen(
                        recordId:
                            document['rental_record_id'].toString(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (total == 0) ...[
              const SizedBox(height: 10),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        size: 38,
                        color: SifaBrand.textGrey,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'Eşleşen kayıt bulunamadı.',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Müşteri adı, şantiye, malzeme veya belge adıyla tekrar deneyebilirsin.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      );

  static IconData _documentIcon(String? type) => switch (type) {
        'contract' => Icons.description_outlined,
        'outbound_delivery' => Icons.north_east,
        'inbound_delivery' => Icons.south_west,
        'invoice' => Icons.receipt_long_outlined,
        _ => Icons.attach_file,
      };

  static String _documentLabel(String? type) => switch (type) {
        'contract' => 'Kira sözleşmesi',
        'outbound_delivery' => 'Giden sevkiyat belgesi',
        'inbound_delivery' => 'Gelen / iade belgesi',
        'invoice' => 'Fatura',
        _ => 'Diğer belge',
      };
}

class _ResultCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final AppStatusTone tone;
  final VoidCallback onTap;

  const _ResultCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      AppStatusTone.info => (SifaBrand.infoBg, SifaBrand.info),
      AppStatusTone.success => (SifaBrand.successBg, SifaBrand.success),
      AppStatusTone.warning =>
        (const Color(0xFFFFF4E5), const Color(0xFF9A5D00)),
      _ => (SifaBrand.ivory, SifaBrand.textGrey),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.$1,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: palette.$2, size: 21),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          subtitle: subtitle == null || subtitle!.trim().isEmpty
              ? null
              : Text(subtitle!),
          trailing: const Icon(
            Icons.chevron_right,
            color: SifaBrand.deepGold,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
