import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'local_domain_cache.dart';
import 'offline_sync_service.dart';

class RentalApiRepository {
  RentalApiRepository({
    ApiClient? api,
    OfflineSyncService? queue,
    LocalDomainCache? cache,
  })  : api = api ?? ApiClient(),
        queue = queue ?? OfflineSyncService(),
        cache = cache ?? LocalDomainCache();

  final ApiClient api;
  final OfflineSyncService queue;
  final LocalDomainCache cache;
  final uuid = const Uuid();

  Future<List<Map<String, dynamic>>> products() async {
    final data = await api.getJson('/products') as List;
    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> rentalsForCustomerOfflineFirst(
    String customerId,
  ) async {
    final local = await cache.rentalsForCustomer(customerId);
    var result = local
        .map(
          (r) => {
            'id': r.id,
            'customer_id': r.customerId,
            'address_id': r.addressId,
            'original_outbound_date':
                r.originalOutboundDate.toIso8601String(),
            'invoice_preference': r.invoicePreference,
            'status': r.status,
            'note': r.note,
            'pending_sync': r.pendingSync,
            'row_version': r.rowVersion,
          },
        )
        .toList();

    if (ApiConfig.configured) {
      try {
        final raw = await api.getJson(
          '/customers/$customerId/rentals',
        ) as List;

        result = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        for (final r in result) {
          await cache.upsertRental(
            id: r['id'].toString(),
            customerId: customerId,
            addressId: r['address_id']?.toString(),
            originalOutboundDate:
                DateTime.parse(r['original_outbound_date'].toString()),
            invoicePreference:
                r['invoice_preference']?.toString() ?? 'no_invoice',
            status: r['status']?.toString() ?? 'active',
            note: r['note']?.toString(),
            pendingSync: false,
            rowVersion: (r['row_version'] as num?)?.toInt() ?? 1,
          );

          final items = (r['items'] as List?) ?? const [];
          for (final rawItem in items) {
            final item = Map<String, dynamic>.from(rawItem as Map);
            await cache.upsertRentalItem(
              id: item['id'].toString(),
              rentalId: r['id'].toString(),
              productId: item['product_id'].toString(),
              initialQuantity:
                  (item['initial_quantity'] as num).toDouble(),
              pendingSync: false,
            );
          }
        }
      } catch (_) {}
    }

    return result;
  }

  Future<Map<String, dynamic>> refreshRentalFromServer(
    String rentalId,
  ) async {
    final data = await api.getJson('/rentals/$rentalId');
    final cloud = Map<String, dynamic>.from(data as Map);
    await _cacheCloudDetail(cloud);
    return cloud;
  }

  Future<Map<String, dynamic>> rentalDetailOfflineFirst(
    String rentalId,
  ) async {
    final local = await _localDetail(rentalId);

    if (ApiConfig.configured) {
      try {
        final data = await api.getJson('/rentals/$rentalId');
        final cloud = Map<String, dynamic>.from(data as Map);
        await _cacheCloudDetail(cloud);
        return cloud;
      } catch (_) {}
    }

    if (local != null) return local;
    throw StateError('Kiralama kaydı cihazda bulunamadı.');
  }

  Future<String> createOfflineSafe(
    Map<String, dynamic> payload,
  ) async {
    final operationId = uuid.v4();
    final rentalId = payload['id']?.toString() ?? uuid.v4();

    final items = ((payload['items'] as List?) ?? const [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .map((item) {
          final firstRate = item['first_rate_amount'];
          return {
            ...item,
            'id': item['id']?.toString() ?? uuid.v4(),
            'outbound_movement_id':
                item['outbound_movement_id']?.toString() ?? uuid.v4(),
            'first_rate_id': firstRate == null
                ? null
                : (item['first_rate_id']?.toString() ?? uuid.v4()),
          };
        })
        .toList();

    final body = {
      ...payload,
      'id': rentalId,
      'items': items,
    };

    final outboundDate =
        DateTime.parse(body['original_outbound_date'].toString());

    await cache.upsertRental(
      id: rentalId,
      customerId: body['customer_id'].toString(),
      addressId: body['address_id']?.toString(),
      originalOutboundDate: outboundDate,
      invoicePreference:
          body['invoice_preference']?.toString() ?? 'no_invoice',
      status: 'active',
      note: body['note']?.toString(),
      pendingSync: true,
    );

    for (final item in items) {
      await cache.upsertRentalItem(
        id: item['id'].toString(),
        rentalId: rentalId,
        productId: item['product_id'].toString(),
        initialQuantity: (item['quantity'] as num).toDouble(),
        pendingSync: true,
      );

      final movementId = item['outbound_movement_id'].toString();
      await cache.upsertMovement(
        id: movementId,
        rentalId: rentalId,
        rentalItemId: item['id'].toString(),
        productId: item['product_id'].toString(),
        movementType: 'outbound',
        quantity: (item['quantity'] as num).toDouble(),
        movementDate: outboundDate,
        pendingSync: true,
      );

      final firstRate = item['first_rate_amount'];
      if (firstRate != null) {
        await cache.upsertRate(
          id: item['first_rate_id'].toString(),
          rentalId: rentalId,
          rentalItemId: item['id'].toString(),
          productId: item['product_id'].toString(),
          effectiveFrom: outboundDate,
          amount: (firstRate as num).toDouble(),
          rateType:
              item['rate_type']?.toString() ?? 'per_unit_monthly',
          pendingSync: true,
        );
      }
    }

    if (ApiConfig.configured) {
      try {
        await api.postJson(
          '/rentals',
          {
            ...body,
            'client_operation_id': operationId,
          },
        );

        await cache.upsertRental(
          id: rentalId,
          customerId: body['customer_id'].toString(),
          addressId: body['address_id']?.toString(),
          originalOutboundDate: outboundDate,
          invoicePreference:
              body['invoice_preference']?.toString() ?? 'no_invoice',
          status: 'active',
          note: body['note']?.toString(),
          pendingSync: false,
        );

        return rentalId;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createRental,
      body,
    );
    return rentalId;
  }

  Future<String> addReturnOfflineSafe({
    required String rentalId,
    required String rentalItemId,
    required String productId,
    required double quantity,
    required DateTime movementDate,
    required String returnCondition,
    String? note,
  }) async {
    final operationId = uuid.v4();
    final movementId = uuid.v4();

    await cache.upsertMovement(
      id: movementId,
      rentalId: rentalId,
      rentalItemId: rentalItemId,
      productId: productId,
      movementType: 'inbound_return',
      quantity: quantity,
      movementDate: movementDate,
      returnCondition: returnCondition,
      note: note,
      pendingSync: true,
    );

    final payload = {
      'id': movementId,
      'rental_record_id': rentalId,
      'rental_item_id': rentalItemId,
      'product_id': productId,
      'quantity': quantity,
      'movement_date': movementDate.toIso8601String(),
      'return_condition': returnCondition,
      'note': note,
    };

    if (ApiConfig.configured) {
      try {
        await api.postJson(
          '/rentals/$rentalId/returns',
          {
            'id': movementId,
            'rental_item_id': rentalItemId,
            'quantity': quantity,
            'movement_date': _date(movementDate),
            'return_condition': returnCondition,
            'note': note,
            'client_operation_id': operationId,
          },
        );
        await cache.upsertMovement(
          id: movementId,
          rentalId: rentalId,
          rentalItemId: rentalItemId,
          productId: productId,
          movementType: 'inbound_return',
          quantity: quantity,
          movementDate: movementDate,
          returnCondition: returnCondition,
          note: note,
          pendingSync: false,
        );
        return movementId;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.addReturn,
      payload,
    );
    return movementId;
  }

  Future<String> addRateOfflineSafe({
    required String rentalId,
    required String rentalItemId,
    required String productId,
    required DateTime effectiveFrom,
    required double amount,
    required String rateType,
    String? note,
  }) async {
    final operationId = uuid.v4();
    final rateId = uuid.v4();

    await cache.upsertRate(
      id: rateId,
      rentalId: rentalId,
      rentalItemId: rentalItemId,
      productId: productId,
      effectiveFrom: effectiveFrom,
      amount: amount,
      rateType: rateType,
      pendingSync: true,
    );

    final payload = {
      'id': rateId,
      'rental_record_id': rentalId,
      'rental_item_id': rentalItemId,
      'product_id': productId,
      'effective_from': effectiveFrom.toIso8601String(),
      'amount': amount,
      'rate_type': rateType,
      'note': note,
    };

    if (ApiConfig.configured) {
      try {
        await api.postJson(
          '/rentals/$rentalId/rates',
          {
            'id': rateId,
            'rental_item_id': rentalItemId,
            'effective_from': _date(effectiveFrom),
            'amount': amount,
            'rate_type': rateType,
            'note': note,
            'client_operation_id': operationId,
          },
        );
        await cache.upsertRate(
          id: rateId,
          rentalId: rentalId,
          rentalItemId: rentalItemId,
          productId: productId,
          effectiveFrom: effectiveFrom,
          amount: amount,
          rateType: rateType,
          pendingSync: false,
        );
        return rateId;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.addRate,
      payload,
    );
    return rateId;
  }

  Future<void> setInvoicePreferenceOfflineSafe({
    required String rentalId,
    required String invoicePreference,
  }) async {
    final operationId = uuid.v4();
    final existing = await cache.rental(rentalId);
    if (existing == null) return;

    final expectedVersion = existing.rowVersion;
    await cache.upsertRental(
      id: existing.id,
      customerId: existing.customerId,
      addressId: existing.addressId,
      originalOutboundDate: existing.originalOutboundDate,
      invoicePreference: invoicePreference,
      status: existing.status,
      note: existing.note,
      pendingSync: true,
      rowVersion: expectedVersion + 1,
    );

    final payload = {
      'rental_record_id': rentalId,
      'invoice_preference': invoicePreference,
      'expected_version': expectedVersion,
    };

    if (ApiConfig.configured) {
      try {
        await api.patchJson(
          '/rentals/$rentalId/invoice-preference',
          {
            'invoice_preference': invoicePreference,
            'expected_version': expectedVersion,
            'client_operation_id': operationId,
          },
        );
        await cache.upsertRental(
          id: existing.id,
          customerId: existing.customerId,
          addressId: existing.addressId,
          originalOutboundDate: existing.originalOutboundDate,
          invoicePreference: invoicePreference,
          status: existing.status,
          note: existing.note,
          pendingSync: false,
          rowVersion: expectedVersion + 1,
        );
        return;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.changeInvoicePreference,
      payload,
    );
  }

  Future<Map<String, dynamic>?> _localDetail(String rentalId) async {
    final r = await cache.rental(rentalId);
    if (r == null) return null;

    final customer = await cache.customer(r.customerId);
    final address = r.addressId == null
        ? null
        : await cache.address(r.addressId!);
    final items = await cache.rentalItems(rentalId);
    final movements = await cache.movements(rentalId);
    final rates = await cache.rates(rentalId);
    final documents = await cache.documents(rentalId);
    final billing = await cache.billingPeriods(rentalId);
    final localProducts = await cache.products();

    final productById = {
      for (final p in localProducts) p.id: p,
    };

    return {
      'rental': {
        'id': r.id,
        'customer_id': r.customerId,
        'customer_name': customer?.name ?? 'Müşteri',
        'address_id': r.addressId,
        'address_label': address?.label,
        'full_address': address?.fullAddress,
        'original_outbound_date':
            r.originalOutboundDate.toIso8601String(),
        'invoice_preference': r.invoicePreference,
        'status': r.status,
        'note': r.note,
        'pending_sync': r.pendingSync,
        'row_version': r.rowVersion,
      },
      'items': items.map((i) {
        final p = productById[i.productId];
        final returned = movements
            .where(
              (m) =>
                  m.rentalItemId == i.id &&
                  m.movementType == 'inbound_return',
            )
            .fold<double>(0, (sum, m) => sum + m.quantity);

        return {
          'id': i.id,
          'product_id': i.productId,
          'product_name': p?.name ?? i.productId,
          'unit': p?.unit ?? 'piece',
          'initial_quantity': i.initialQuantity,
          'returned_quantity': returned,
          'pending_sync': i.pendingSync,
        };
      }).toList(),
      'movements': movements
          .map(
            (m) => {
              'id': m.id,
              'rental_record_id': m.rentalId,
              'rental_item_id': m.rentalItemId,
              'product_id': m.productId,
              'movement_type': m.movementType,
              'quantity': m.quantity,
              'movement_date': m.movementDate.toIso8601String(),
              'return_condition': m.returnCondition,
              'note': m.note,
              'pending_sync': m.pendingSync,
            },
          )
          .toList(),
      'rates': rates
          .map(
            (rr) => {
              'id': rr.id,
              'rental_record_id': rr.rentalId,
              'rental_item_id': rr.rentalItemId,
              'product_id': rr.productId,
              'effective_from': rr.effectiveFrom.toIso8601String(),
              'amount': rr.amount,
              'rate_type': rr.rateType,
              'product_name':
                  productById[rr.productId]?.name ?? rr.productId,
              'unit': productById[rr.productId]?.unit ?? 'piece',
              'pending_sync': rr.pendingSync,
            },
          )
          .toList(),
      'documents': documents
          .map(
            (d) => {
              'id': d.id,
              'rental_movement_id': d.movementId,
              'document_type': d.documentType,
              'original_file_name': d.originalFileName,
              'created_at': d.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'billing_periods': billing
          .map(
            (b) => {
              'id': b.id,
              'rental_record_id': b.rentalId,
              'renewal_date': b.renewalDate.toIso8601String(),
              'invoice_status': b.invoiceStatus,
              'payment_status': b.paymentStatus,
              'billed_amount': b.billedAmount,
              'paid_amount': b.paidAmount,
              'invoice_no': b.invoiceNo,
              'invoice_date': b.invoiceDate?.toIso8601String(),
              'payment_due_date': b.paymentDueDate?.toIso8601String(),
              'quantity_rate_snapshot': b.snapshotJson == null
                  ? const []
                  : jsonDecode(b.snapshotJson!),
              'row_version': b.rowVersion,
              'pending_sync': b.pendingSync,
            },
          )
          .toList(),
    };
  }

  Future<void> _cacheCloudDetail(
    Map<String, dynamic> cloud,
  ) async {
    final rental =
        Map<String, dynamic>.from(cloud['rental'] as Map);
    final rentalId = rental['id'].toString();

    final customerId = rental['customer_id'].toString();
    final existingCustomer = await cache.customer(customerId);
    await cache.upsertCustomer(
      id: customerId,
      name: rental['customer_name']?.toString() ?? 'Müşteri',
      phone: existingCustomer?.phone,
      notes: existingCustomer?.notes,
      pendingSync: false,
    );

    if (rental['address_id'] != null) {
      await cache.upsertAddress(
        id: rental['address_id'].toString(),
        customerId: rental['customer_id'].toString(),
        label: rental['address_label']?.toString() ?? 'Şantiye',
        fullAddress: rental['full_address']?.toString(),
        pendingSync: false,
      );
    }

    await cache.upsertRental(
      id: rentalId,
      customerId: rental['customer_id'].toString(),
      addressId: rental['address_id']?.toString(),
      originalOutboundDate:
          DateTime.parse(rental['original_outbound_date'].toString()),
      invoicePreference:
          rental['invoice_preference']?.toString() ?? 'no_invoice',
      status: rental['status']?.toString() ?? 'active',
      note: rental['note']?.toString(),
      pendingSync: false,
      rowVersion: (rental['row_version'] as num?)?.toInt() ?? 1,
    );

    final items = (cloud['items'] as List?) ?? const [];
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);
      await cache.upsertRentalItem(
        id: item['id'].toString(),
        rentalId: rentalId,
        productId: item['product_id'].toString(),
        initialQuantity:
            (item['initial_quantity'] as num).toDouble(),
        pendingSync: false,
      );
    }

    final movements = (cloud['movements'] as List?) ?? const [];
    for (final raw in movements) {
      final m = Map<String, dynamic>.from(raw as Map);
      final rentalItemId = m['rental_item_id'].toString();
      final item = items
          .map((e) => Map<String, dynamic>.from(e as Map))
          .firstWhere((i) => i['id'].toString() == rentalItemId);

      await cache.upsertMovement(
        id: m['id'].toString(),
        rentalId: rentalId,
        rentalItemId: rentalItemId,
        productId: item['product_id'].toString(),
        movementType: m['movement_type'].toString(),
        quantity: (m['quantity'] as num).toDouble(),
        movementDate:
            DateTime.parse(m['movement_date'].toString()),
        returnCondition: m['return_condition']?.toString(),
        note: m['note']?.toString(),
        pendingSync: false,
      );
    }

    final rates = (cloud['rates'] as List?) ?? const [];
    for (final raw in rates) {
      final rr = Map<String, dynamic>.from(raw as Map);
      final rentalItemId = rr['rental_item_id'].toString();
      final item = items
          .map((e) => Map<String, dynamic>.from(e as Map))
          .firstWhere((i) => i['id'].toString() == rentalItemId);

      await cache.upsertRate(
        id: rr['id'].toString(),
        rentalId: rentalId,
        rentalItemId: rentalItemId,
        productId: item['product_id'].toString(),
        effectiveFrom:
            DateTime.parse(rr['effective_from'].toString()),
        amount: (rr['amount'] as num).toDouble(),
        rateType: rr['rate_type'].toString(),
        pendingSync: false,
      );
    }

    await cache.replaceDocuments(
      rentalId,
      ((cloud['documents'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );

    await cache.replaceBillingPeriods(
      rentalId,
      ((cloud['billing_periods'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
