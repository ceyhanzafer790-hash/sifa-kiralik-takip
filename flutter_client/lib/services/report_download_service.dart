import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

class ReportDownloadService {
  ReportDownloadService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<String> download({
    required String reportType,
    required String format,
    Map<String, String?> filters = const {},
  }) async {
    final query = <String, String>{
      'format': format,
      for (final entry in filters.entries)
        if (entry.value != null && entry.value!.trim().isNotEmpty)
          entry.key: entry.value!,
    };

    final qs = query.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final bytes = await api.getBytes(
      '/reports/$reportType?$qs',
    );

    return _save(
      bytes,
      'sifa_${reportType}_${_date(DateTime.now())}.$format',
    );
  }

  Future<String> downloadCustomerStatement({
    required String customerId,
    required String customerName,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final query = <String, String>{
      'customer_id': customerId,
      if (fromDate != null) 'from_date': _date(fromDate),
      if (toDate != null) 'to_date': _date(toDate),
    };

    final qs = query.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}='
              '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');

    final bytes = await api.getBytes(
      '/reports/customer-statement?$qs',
    );

    final safe = customerName
        .replaceAll(RegExp(r'[^A-Za-z0-9ÇĞİÖŞÜçğıöşü]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    return _save(
      bytes,
      'sifa_ekstre_${safe.isEmpty ? "musteri" : safe}_${_date(DateTime.now())}.xlsx',
    );
  }

  Future<String> _save(Uint8List bytes, String fileName) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(base.path, 'SifaRaporlar'),
    );
    await dir.create(recursive: true);

    var path = p.join(dir.path, fileName);
    var counter = 2;

    while (await File(path).exists()) {
      final ext = p.extension(fileName);
      final stem = p.basenameWithoutExtension(fileName);
      path = p.join(dir.path, '${stem}_$counter$ext');
      counter++;
    }

    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
