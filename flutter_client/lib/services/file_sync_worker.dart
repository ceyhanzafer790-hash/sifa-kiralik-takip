import 'package:drift/drift.dart';

import '../database/local_database.dart';
import 'document_api_service.dart';
import 'offline_document_queue.dart';

class FileSyncWorker {
  FileSyncWorker({
    AppDatabase? db,
    OfflineDocumentQueue? queue,
    DocumentApiService? documents,
  })  : db = db ?? AppDatabase.instance,
        queue = queue ?? OfflineDocumentQueue(),
        documents = documents ?? DocumentApiService();

  final AppDatabase db;
  final OfflineDocumentQueue queue;
  final DocumentApiService documents;

  Future<FileSyncResult> flush() async {
    final now = DateTime.now();
    final rows = await (db.select(db.pendingFileUploads)
          ..where((r) => r.nextAttemptAt.isNull() | r.nextAttemptAt.isSmallerOrEqualValue(now))
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .get();

    var sent = 0;
    var failed = 0;

    for (final row in rows) {
      try {
        await documents.uploadLocalFile(
          rentalRecordId: row.rentalRecordId,
          rentalMovementId: row.rentalMovementId,
          documentType: row.documentType,
          localPath: row.localPath,
          originalFileName: row.originalFileName,
        );
        await queue.removeAndDeleteFile(row.id);
        sent++;
      } catch (e) {
        await queue.markFailure(row.id, e);
        failed++;
      }
    }

    return FileSyncResult(
      sent: sent,
      failed: failed,
      remaining: await queue.count(),
    );
  }
}

class FileSyncResult {
  final int sent;
  final int failed;
  final int remaining;

  const FileSyncResult({
    required this.sent,
    required this.failed,
    required this.remaining,
  });
}
