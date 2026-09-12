import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';

class OfflineDocumentQueue {
  OfflineDocumentQueue({AppDatabase? db})
      : db = db ?? AppDatabase.instance;

  final AppDatabase db;
  final _uuid = const Uuid();

  Future<String?> pickAndQueue({
    required String rentalRecordId,
    required String documentType,
    String? rentalMovementId,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'doc',
        'docx',
        'xlsx',
      ],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('Dosya güvenli yerel kuyruğa kopyalanamadı.');
    }

    final supportDir = await getApplicationSupportDirectory();
    final queueDir = Directory(
      p.join(supportDir.path, 'pending_uploads'),
    );
    await queueDir.create(recursive: true);

    final id = _uuid.v4();
    final ext = p.extension(file.name).toLowerCase();
    final localFile = File(p.join(queueDir.path, '$id$ext'));
    await localFile.writeAsBytes(bytes, flush: true);

    await db.into(db.pendingFileUploads).insert(
          PendingFileUploadsCompanion.insert(
            id: id,
            rentalRecordId: rentalRecordId,
            rentalMovementId: Value(rentalMovementId),
            documentType: documentType,
            localPath: localFile.path,
            originalFileName: file.name,
            mimeType: const Value(null),
            createdAt: DateTime.now(),
          ),
        );

    return id;
  }

  Future<int> count() async {
    final exp = db.pendingFileUploads.id.count();
    final query = db.selectOnly(db.pendingFileUploads)..addColumns([exp]);
    final row = await query.getSingle();
    return row.read(exp) ?? 0;
  }

  Future<void> removeAndDeleteFile(String id) async {
    final row = await (db.select(db.pendingFileUploads)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();

    if (row != null) {
      final file = File(row.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await (db.delete(db.pendingFileUploads)
          ..where((r) => r.id.equals(id)))
        .go();
  }

  Future<void> markFailure(String id, Object error) async {
    final row = await (db.select(db.pendingFileUploads)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();

    if (row == null) return;

    final nextAttempts = row.attempts + 1;
    final minutes = switch (nextAttempts) {
      1 => 1,
      2 => 2,
      3 => 5,
      4 => 15,
      5 => 30,
      _ => 60,
    };

    await (db.update(db.pendingFileUploads)
          ..where((r) => r.id.equals(id)))
        .write(
      PendingFileUploadsCompanion(
        attempts: Value(nextAttempts),
        lastError: Value(error.toString()),
        nextAttemptAt: Value(DateTime.now().add(Duration(minutes: minutes))),
      ),
    );
  }
}
