import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_config.dart';
import '../services/customer_api_repository.dart';
import '../services/local_domain_cache.dart';
import '../widgets/sifa_brand.dart';
import 'customer_create_screen.dart';
import 'rental_create_screen.dart';

class ShipmentScreen extends StatefulWidget {
  const ShipmentScreen({super.key});

  @override
  State<ShipmentScreen> createState() => _ShipmentScreenState();
}

class _ShipmentScreenState extends State<ShipmentScreen> {
  final repo = CustomerApiRepository();
  final cache = LocalDomainCache();

  bool loading = true;
  String query = '';
  List<Customer> customers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    final local = await cache.customers();
    var result = local
        .map((r) => Customer(id: r.id, name: r.name))
        .toList();

    if (mounted) setState(() => customers = result);

    if (ApiConfig.configured) {
      try {
        final cloud = await repo.list();
        result = cloud
            .map(
              (r) => Customer(
                id: r['id'].toString(),
                name: r['name'].toString(),
              ),
            )
            .toList();

        for (final r in cloud) {
          await cache.upsertCustomer(
            id: r['id'].toString(),
            name: r['name'].toString(),
            phone: r['phone']?.toString(),
            notes: r['notes']?.toString(),
            pendingSync: false,
          );
        }

        if (mounted) setState(() => customers = result);
      } catch (_) {
        // Sunucu yoksa gerçek yerel müşteri cache'i kullanılmaya devam eder.
      }
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _createCustomer() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CustomerCreateScreen()),
    );
    if (id != null) await _load();
  }

  Future<void> _startRental(Customer customer) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RentalCreateScreen(customer: customer),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = customers
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Yeni Sevkiyat',
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
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: SifaBrand.charcoal,
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: SifaBrand.gold.withOpacity(0.45),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.local_shipping_outlined,
                            color: SifaBrand.gold,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kiralık Malzeme Gönder',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Önce müşteriyi seç, sonra şantiye ve malzemeleri ekle.',
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
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StepPill(
                            number: '1',
                            label: 'Müşteri',
                            active: true,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: _StepPill(
                            number: '2',
                            label: 'Şantiye',
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: _StepPill(
                            number: '3',
                            label: 'Malzeme',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Müşteri ara',
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Yeni müşteri ekle',
                  onPressed: _createCustomer,
                  icon: const Icon(Icons.person_add_alt_1),
                ),
              ],
            ),
            if (loading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    q.isEmpty ? 'Müşteri Seç' : 'Arama Sonuçları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: SifaBrand.goldBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${filtered.length}',
                    style: const TextStyle(
                      color: SifaBrand.deepGold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            if (!loading && filtered.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SifaBuildingMark(size: 44, gold: false),
                      const SizedBox(height: 10),
                      Text(
                        q.isEmpty
                            ? 'Henüz müşteri kaydı yok.'
                            : 'Aramana uyan müşteri bulunamadı.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _createCustomer,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Yeni Müşteri Ekle'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filtered.map(
                (customer) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: SifaBrand.gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const SifaBuildingMark(size: 29),
                      ),
                      title: Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                      subtitle: const Text(
                        'Kiralık çıkış / sevkiyat oluştur',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: SifaBrand.deepGold,
                      ),
                      onTap: () => _startRental(customer),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _StepPill extends StatelessWidget {
  final String number;
  final String label;
  final bool active;

  const _StepPill({
    required this.number,
    required this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: active ? SifaBrand.goldBg : SifaBrand.ivory,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: active
              ? SifaBrand.gold.withOpacity(0.35)
              : SifaBrand.softGrey,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: active ? SifaBrand.gold : SifaBrand.softGrey,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                color: active ? SifaBrand.charcoal : SifaBrand.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? SifaBrand.charcoal : SifaBrand.textGrey,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
