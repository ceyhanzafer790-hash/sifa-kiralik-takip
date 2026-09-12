import 'dart:convert';

import '../database/local_database.dart';
import 'api_client.dart';
import 'offline_sync_service.dart';
import 'local_domain_cache.dart';
import 'conflict_service.dart';
import 'rental_api_repository.dart';

class SyncWorker {
  SyncWorker({
    OfflineSyncService? queue,
    ApiClient? api,
    AppDatabase? db,
    LocalDomainCache? cache,
    ConflictService? conflicts,
  })  : queue = queue ?? OfflineSyncService(),
        api = api ?? ApiClient(),
        db = db ?? AppDatabase.instance,
        cache = cache ?? LocalDomainCache(),
        conflicts = conflicts ?? ConflictService();

  final OfflineSyncService queue;
  final ApiClient api;
  final AppDatabase db;
  final LocalDomainCache cache;
  final ConflictService conflicts;

  Future<SyncRunResult> runFullSync() async {
    final push = await flushPending();
    final pulled = await pullChanges();

    return SyncRunResult(
      sent: push.sent,
      failed: push.failed,
      remaining: push.remaining,
      pulled: pulled,
      conflicts: push.conflicts,
    );
  }

  Future<SyncRunResult> flushPending() async {
    final pending = await queue.due();
    var sent = 0;
    var failed = 0;

    var conflictCount = 0;

    for (final op in pending) {
      try {
        await _send(op);
        await _ackLocal(op);
        await queue.remove(op.id);
        sent++;
      } on ApiException catch (e) {
        if (e.statusCode == 409 &&
            e.code == 'operation_already_processed') {
          await _ackLocal(op);
          await queue.remove(op.id);
          sent++;
          continue;
        }

        if (e.statusCode == 409 &&
            e.code == 'row_version_conflict') {
          await conflicts.record(op, e);
          await queue.remove(op.id);
          conflictCount++;
          continue;
        }

        await queue.markFailure(op.id, e);
        failed++;
      } catch (e) {
        await queue.markFailure(op.id, e);
        failed++;
      }
    }

    return SyncRunResult(
      sent: sent,
      failed: failed,
      remaining: await queue.count(),
      pulled: 0,
      conflicts: conflictCount,
    );
  }

  Future<int> pullChanges() async {
    var cursor = int.tryParse(
          await db.getSyncState('last_server_seq') ?? '0',
        ) ??
        0;

    var total = 0;
    var hasMore = true;

    while (hasMore) {
      final refreshedRentals = <String>{};
      final response = await api.getJson(
        '/sync/changes?after=$cursor&limit=250',
      ) as Map<String, dynamic>;

      final changes = (response['changes'] as List?) ?? const [];
      for (final raw in changes) {
        final change = Map<String, dynamic>.from(raw as Map);
        final seq = (change['seq'] as num).toInt();
        final type = change['entity_type'].toString();
        final id = change['entity_id'].toString();
        final action = change['action'].toString();

        await _applyTypedChange(
          change,
          refreshedRentals,
        );

        if (action == 'deleted') {
          await db.removeCached(type, id);
        } else {
          await db.cacheEntity(
            entityType: type,
            entityId: id,
            jsonData: jsonEncode(change),
            serverSeq: seq,
          );
        }

        if (seq > cursor) cursor = seq;
        total++;
      }

      await db.setSyncState('last_server_seq', '$cursor');
      hasMore = response['has_more'] == true;
    }

    return total;
  }

  Future<void> _applyTypedChange(
    Map<String, dynamic> change,
    Set<String> refreshedRentals,
  ) async {
    final type = change['entity_type']?.toString() ?? '';
    final action = change['action']?.toString() ?? '';
    if (action == 'deleted') return;

    final rawPayload = change['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};

    switch (type) {
      case 'customer':
        if (payload['id'] == null || payload['name'] == null) return;
        await cache.upsertCustomer(
          id: payload['id'].toString(),
          name: payload['name'].toString(),
          phone: payload['phone']?.toString(),
          notes: payload['notes']?.toString(),
          pendingSync: false,
        );

      case 'customer_address':
        if (payload['id'] == null ||
            payload['customer_id'] == null ||
            payload['label'] == null) {
          return;
        }
        await cache.upsertAddress(
          id: payload['id'].toString(),
          customerId: payload['customer_id'].toString(),
          label: payload['label'].toString(),
          fullAddress: payload['full_address']?.toString(),
          pendingSync: false,
        );

      case 'rental_record':
        await _refreshRentalOnce(
          change['entity_id']?.toString(),
          refreshedRentals,
        );

      case 'rental_billing_period':
      case 'rental_document':
        await _refreshRentalOnce(
          payload['rental_record_id']?.toString(),
          refreshedRentals,
        );

      default:
        break;
    }
  }

  Future<void> _refreshRentalOnce(
    String? rentalId,
    Set<String> refreshedRentals,
  ) async {
    if (rentalId == null || rentalId.isEmpty) return;
    if (!refreshedRentals.add(rentalId)) return;

    await RentalApiRepository(
      api: api,
      queue: queue,
      cache: cache,
    ).refreshRentalFromServer(rentalId);
  }

  Future<void> _send(PendingSyncOperation op) async {
    final p = Map<String, dynamic>.from(op.payload);

    switch (op.type) {
      case SyncOperationType.createCustomer:
        await api.postJson(
          '/customers',
          {
            ...p,
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.createCustomerAddress:
        await api.postJson(
          '/customers/${p['customer_id']}/addresses',
          {
            'id': p['id'],
            'label': p['label'],
            'full_address': p['full_address'],
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.createRental:
        await api.postJson(
          '/rentals',
          {
            ...p,
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.addReturn:
        await api.postJson(
          '/rentals/${p['rental_record_id']}/returns',
          {
            'id': p['id'],
            'rental_item_id': p['rental_item_id'],
            'quantity': p['quantity'],
            'movement_date': _dateString(p['movement_date']),
            'return_condition': p['return_condition'] ?? 'usable',
            'note': p['note'],
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.addRate:
        await api.postJson(
          '/rentals/${p['rental_record_id']}/rates',
          {
            'id': p['id'],
            'rental_item_id': p['rental_item_id'],
            'effective_from': _dateString(p['effective_from']),
            'amount': p['amount'],
            'rate_type': _mapRateType(p['rate_type']),
            'note': p['note'],
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.changeInvoicePreference:
        await api.patchJson(
          '/rentals/${p['rental_record_id']}/invoice-preference',
          {
            'invoice_preference':
                _mapInvoicePreference(p['invoice_preference']),
            'expected_version': p['expected_version'],
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.createBillingPeriod:
        await api.postJson(
          '/rentals/${p['rental_record_id']}/billing-periods',
          {
            'renewal_date': _dateString(p['renewal_date']),
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.updateBillingPeriod:
        await api.patchJson(
          '/rentals/${p['rental_record_id']}/billing-periods/by-date/${_dateString(p['renewal_date'])}',
          {
            ...p,
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.createSale:
        await api.postJson(
          '/sales',
          {
            ...p,
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.createStockCount:
        await api.postJson(
          '/stock/counts',
          {
            ...p,
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.createOpeningStock:
        await api.postJson(
          '/stock/opening',
          {
            ...p,
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.createPurchase:
        await api.postJson(
          '/purchases',
          {
            ...p,
            'client_operation_id': op.id,
          },
        );

      case SyncOperationType.uploadDocumentMetadata:
        throw StateError(
          'Belge byte dosyaları ayrı kalıcı dosya kuyruğuna taşınacak.',
        );
    }
  }


  Future<void> _ackLocal(PendingSyncOperation op) async {
    final p = Map<String, dynamic>.from(op.payload);
    switch (op.type) {
      case SyncOperationType.createCustomer:
        await cache.markCustomerSynced(p['id'].toString());
      case SyncOperationType.createCustomerAddress:
        await cache.markAddressSynced(p['id'].toString());
      case SyncOperationType.createRental:
        await cache.markRentalSynced(p['id'].toString());
        final items = ((p['items'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map));
        for (final item in items) {
          await cache.markRentalItemSynced(item['id'].toString());
          await cache.markMovementSynced(item['outbound_movement_id'].toString());
          if (item['first_rate_id'] != null) {
            await cache.markRateSynced(item['first_rate_id'].toString());
          }
        }
      case SyncOperationType.addReturn:
        await cache.markMovementSynced(p['id'].toString());
      case SyncOperationType.addRate:
        await cache.markRateSynced(p['id'].toString());
      case SyncOperationType.changeInvoicePreference:
        await cache.markRentalSynced(p['rental_record_id'].toString());
      case SyncOperationType.createBillingPeriod:
      case SyncOperationType.updateBillingPeriod:
        final period = await cache.billingPeriodByDate(
          p['rental_record_id'].toString(),
          DateTime.parse(p['renewal_date'].toString()),
        );
        if (period != null) await cache.markBillingPeriodSynced(period.id);
      default:
        break;
    }
  }

  String _dateString(dynamic value) {
    final d = DateTime.parse(value.toString());
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _mapRateType(dynamic value) {
    final s = value.toString();
    return s.contains('fixed') ? 'fixed_monthly' : 'per_unit_monthly';
  }

  String _mapInvoicePreference(dynamic value) {
    final s = value.toString();
    return s.contains('invoiceRequired') || s == 'invoice_required'
        ? 'invoice_required'
        : 'no_invoice';
  }
}

class SyncRunResult {
  final int sent;
  final int failed;
  final int remaining;
  final int pulled;
  final int conflicts;

  const SyncRunResult({
    required this.sent,
    required this.failed,
    required this.remaining,
    required this.pulled,
    this.conflicts = 0,
  });
}
