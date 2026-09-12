import 'package:drift/drift.dart';

import '../database/local_database.dart';
import 'api_client.dart';
import 'api_config.dart';

class GlobalSearchRepository {
  GlobalSearchRepository({ApiClient? api, AppDatabase? db})
      : api = api ?? ApiClient(),
        db = db ?? AppDatabase.instance;

  final ApiClient api;
  final AppDatabase db;

  Future<Map<String, dynamic>> search(String query) async {
    final local = await _local(query);
    if (ApiConfig.configured) {
      try {
        final data = await api.getJson(
          '/search?q=${Uri.encodeQueryComponent(query)}&limit=30',
        );
        return Map<String, dynamic>.from(data as Map);
      } catch (_) {}
    }
    return local;
  }

  Future<Map<String, dynamic>> _local(String query) async {
    final needle = query.trim().toLowerCase();
    final customersAll = await db.select(db.localCustomers).get();
    final customers = customersAll.where((c) {
      return c.name.toLowerCase().contains(needle) ||
          (c.phone ?? '').toLowerCase().contains(needle);
    }).take(30).toList();

    final documentsAll = await db.select(db.localRentalDocuments).get();
    final documents = documentsAll.where((d) {
      return d.originalFileName.toLowerCase().contains(needle);
    }).take(30).toList();

    final rentalsAll = await db.select(db.localRentals).get();
    final addressesAll = await db.select(db.localAddresses).get();
    final productsAll = await db.select(db.localProducts).get();
    final itemsAll = await db.select(db.localRentalItems).get();

    final customerById = {for (final c in customersAll) c.id: c};
    final addressById = {for (final a in addressesAll) a.id: a};
    final productById = {for (final p in productsAll) p.id: p};
    final rentals = <Map<String, dynamic>>[];

    for (final r in rentalsAll) {
      final customer = customerById[r.customerId];
      final address = r.addressId == null ? null : addressById[r.addressId!];
      final productText = itemsAll
          .where((i) => i.rentalId == r.id)
          .map((i) => productById[i.productId]?.name ?? '')
          .join(' ');
      final haystack = '${customer?.name ?? ''} ${address?.label ?? ''} '
              '${address?.fullAddress ?? ''} $productText'
          .toLowerCase();
      if (haystack.contains(needle)) {
        rentals.add({
          'id': r.id,
          'customer_id': r.customerId,
          'customer_name': customer?.name ?? 'Müşteri',
          'address_label': address?.label,
          'original_outbound_date': r.originalOutboundDate.toIso8601String(),
          'result_type': 'rental',
        });
      }
      if (rentals.length >= 30) break;
    }

    return {
      'query': query,
      'customers': customers.map((c) => {
        'id': c.id, 'name': c.name, 'phone': c.phone, 'result_type': 'customer',
      }).toList(),
      'rentals': rentals,
      'documents': documents.map((d) => {
        'id': d.id,
        'rental_record_id': d.rentalId,
        'original_file_name': d.originalFileName,
        'document_type': d.documentType,
        'result_type': 'document',
      }).toList(),
    };
  }
}
