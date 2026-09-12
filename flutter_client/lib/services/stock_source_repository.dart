import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'offline_sync_service.dart';

class StockSourceRepository {
  StockSourceRepository({
    ApiClient? api,
    OfflineSyncService? queue,
  })  : api = api ?? ApiClient(),
        queue = queue ?? OfflineSyncService();

  final ApiClient api;
  final OfflineSyncService queue;
  final uuid = const Uuid();

  Future<void> openingStock(Map<String, dynamic> payload) async {
    final operationId = uuid.v4();
    if (ApiConfig.configured) {
      try {
        await api.postJson(
          '/stock/opening',
          {...payload, 'client_operation_id': operationId},
        );
        return;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createOpeningStock,
      payload,
    );
  }

  Future<void> purchase(Map<String, dynamic> payload) async {
    final operationId = uuid.v4();
    if (ApiConfig.configured) {
      try {
        await api.postJson(
          '/purchases',
          {...payload, 'client_operation_id': operationId},
        );
        return;
      } catch (_) {}
    }

    await queue.enqueueWithId(
      operationId,
      SyncOperationType.createPurchase,
      payload,
    );
  }
}
