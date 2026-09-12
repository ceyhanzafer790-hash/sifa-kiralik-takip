import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'offline_sync_service.dart';
import 'local_domain_cache.dart';

class CustomerApiRepository {
  CustomerApiRepository({
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

  Future<List<Map<String, dynamic>>> list() async {
    final data = await api.getJson('/customers') as List;
    return data
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }


Future<Map<String, dynamic>?> getByIdOfflineFirst(
  String customerId,
) async {
  final local = await cache.customer(customerId);

  if (ApiConfig.configured) {
    try {
      final raw = await api.getJson(
        '/customers/$customerId',
      );

      final row = Map<String, dynamic>.from(raw as Map);

      await cache.upsertCustomer(
        id: row['id'].toString(),
        name: row['name'].toString(),
        phone: row['phone']?.toString(),
        notes: row['notes']?.toString(),
        pendingSync: false,
      );

      return row;
    } catch (_) {
      // Offline/local fallback aşağıda.
    }
  }

  if (local == null) return null;

  return {
    'id': local.id,
    'name': local.name,
    'phone': local.phone,
    'notes': local.notes,
    'pending_sync': local.pendingSync,
  };
}

  Future<String> createOfflineSafe({
    required String name,
    String? phone,
    String? notes,
  }) async {
    final id = uuid.v4();
    final operationId = uuid.v4();
    final payload = {
      'id': id,
      'name': name.trim(),
      'phone': phone,
      'notes': notes,
    };

    await cache.upsertCustomer(
      id: id,
      name: name.trim(),
      phone: phone,
      notes: notes,
      pendingSync: true,
    );

    if (ApiConfig.configured) {
      try {
        await api.postJson(
          '/customers',
          {...payload, 'client_operation_id': operationId},
        );
        await cache.upsertCustomer(
          id: id,
          name: name.trim(),
          phone: phone,
          notes: notes,
          pendingSync: false,
        );
        return id;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createCustomer,
      payload,
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> addressesOfflineFirst(
    String customerId,
  ) async {
    final localRows = await cache.addresses(customerId);
    var result = localRows
        .map(
          (r) => {
            'id': r.id,
            'customer_id': r.customerId,
            'label': r.label,
            'full_address': r.fullAddress,
            'pending_sync': r.pendingSync,
          },
        )
        .toList();

    if (ApiConfig.configured) {
      try {
        final raw = await api.getJson(
          '/customers/$customerId/addresses',
        ) as List;

        result = raw
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        for (final r in result) {
          await cache.upsertAddress(
            id: r['id'].toString(),
            customerId: customerId,
            label: r['label'].toString(),
            fullAddress: r['full_address']?.toString(),
            pendingSync: false,
          );
        }
      } catch (_) {}
    }

    return result;
  }

  Future<String> addAddressOfflineSafe({
    required String customerId,
    required String label,
    String? fullAddress,
  }) async {
    final id = uuid.v4();
    final operationId = uuid.v4();
    final payload = {
      'id': id,
      'customer_id': customerId,
      'label': label.trim(),
      'full_address': fullAddress,
    };

    await cache.upsertAddress(
      id: id,
      customerId: customerId,
      label: label.trim(),
      fullAddress: fullAddress,
      pendingSync: true,
    );

    if (ApiConfig.configured) {
      try {
        await api.postJson(
          '/customers/$customerId/addresses',
          {
            'id': id,
            'label': label.trim(),
            'full_address': fullAddress,
            'client_operation_id': operationId,
          },
        );
        await cache.upsertAddress(
          id: id,
          customerId: customerId,
          label: label.trim(),
          fullAddress: fullAddress,
          pendingSync: false,
        );
        return id;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createCustomerAddress,
      payload,
    );
    return id;
  }
}
