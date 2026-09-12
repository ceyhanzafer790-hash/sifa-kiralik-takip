import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

class DiagnosticsDownloadService {
  DiagnosticsDownloadService({ApiClient? api})
      : api = api ?? ApiClient();

  final ApiClient api;

  Future<String> download() async {
    final bytes = await api.getBytes(
      '/admin/diagnostics-bundle',
    );

    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(base.path, 'SifaDestek'),
    );
    await dir.create(recursive: true);

    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}';

    final path = p.join(
      dir.path,
      'sifa_diagnostics_$stamp.zip',
    );

    await File(path).writeAsBytes(
      bytes,
      flush: true,
    );

    return path;
  }
}
