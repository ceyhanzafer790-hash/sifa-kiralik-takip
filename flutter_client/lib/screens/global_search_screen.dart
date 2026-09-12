import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/global_search_repository.dart';
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

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  Future<void> _search() async {
    final q = controller.text.trim();
    if (q.isEmpty) return;
    setState(() => loading = true);
    try {
      final data = await repo.search(q);
      if (mounted) setState(() => result = data);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ((result?['customers'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final rentals = ((result?['rentals'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final documents = ((result?['documents'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Genel Arama')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Müşteri, şantiye, malzeme veya belge ara',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward)),
              border: const OutlineInputBorder(),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          if (customers.isNotEmpty) ...[
            _title(context, 'Müşteriler'),
            ...customers.map((c) => Card(child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(c['name'].toString()),
              subtitle: Text(c['phone']?.toString() ?? ''),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CustomerDetailScreen(customer: Customer(id: c['id'].toString(), name: c['name'].toString())),
              )),
            ))),
          ],
          if (rentals.isNotEmpty) ...[
            _title(context, 'Kiralama Takibi'),
            ...rentals.map((r) => Card(child: ListTile(
              leading: const Icon(Icons.event_repeat_outlined),
              title: Text(r['customer_name'].toString()),
              subtitle: Text('${r['address_label'] ?? ''} • ${r['original_outbound_date'] ?? ''}'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RentalTrackingDetailScreen(recordId: r['id'].toString()),
              )),
            ))),
          ],
          if (documents.isNotEmpty) ...[
            _title(context, 'Belgeler'),
            ...documents.map((d) => Card(child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(d['original_file_name'].toString()),
              subtitle: Text(d['document_type'].toString()),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RentalTrackingDetailScreen(recordId: d['rental_record_id'].toString()),
              )),
            ))),
          ],
          if (result != null && customers.isEmpty && rentals.isEmpty && documents.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Eşleşen kayıt bulunamadı.'))),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
  );
}
