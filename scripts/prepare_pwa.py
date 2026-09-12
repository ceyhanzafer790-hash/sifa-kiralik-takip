"""Prepare the Flutter client for a browser/PWA build without changing native behavior."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "flutter_client" / "lib"


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Expected block not found in {path}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


# Drift: keep native SQLite on Android/Windows and use browser storage on web.
db = LIB / "database" / "local_database.dart"
replace_once(
    db,
    "import 'dart:io';\n\nimport 'package:drift/drift.dart';\nimport 'package:drift/native.dart';\nimport 'package:path/path.dart' as p;\nimport 'package:path_provider/path_provider.dart';\n",
    "import 'package:drift/drift.dart';\n\n"
    "import 'database_connection_native.dart'\n"
    "    if (dart.library.html) 'database_connection_web.dart';\n",
)
replace_once(db, "AppDatabase._() : super(_openConnection());", "AppDatabase._() : super(openDatabaseConnection());")
replace_once(
    db,
    "\nLazyDatabase _openConnection() {\n"
    "  return LazyDatabase(() async {\n"
    "    final directory = await getApplicationDocumentsDirectory();\n"
    "    final file = File(p.join(directory.path, 'sifa_kiralik.sqlite'));\n"
    "    return NativeDatabase.createInBackground(file);\n"
    "  });\n"
    "}\n",
    "\n",
)


def conditionalize(service_name: str, web_source: str) -> None:
    public = LIB / "services" / f"{service_name}.dart"
    native = LIB / "services" / f"{service_name}_io.dart"
    web = LIB / "services" / f"{service_name}_web.dart"
    native.write_text(public.read_text(encoding="utf-8"), encoding="utf-8")
    public.write_text(
        f"export '{service_name}_io.dart'\n"
        f"    if (dart.library.html) '{service_name}_web.dart';\n",
        encoding="utf-8",
    )
    web.write_text(web_source, encoding="utf-8")


conditionalize(
    "offline_document_queue",
    """import '../database/local_database.dart';

class OfflineDocumentQueue {
  OfflineDocumentQueue({AppDatabase? db});

  Future<String?> pickAndQueue({
    required String rentalRecordId,
    required String documentType,
    String? rentalMovementId,
  }) async {
    throw UnsupportedError(
      'PWA sürümünde çevrimdışı belge kuyruğu kullanılamıyor. '
      'İnternet bağlantısıyla belgeyi doğrudan yükleyin.',
    );
  }

  Future<int> count() async => 0;
  Future<void> removeAndDeleteFile(String id) async {}
  Future<void> markFailure(String id, Object error) async {}
}
""",
)

conditionalize(
    "report_download_service",
    """import 'dart:html' as html;
import 'dart:typed_data';

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
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final bytes = await api.getBytes('/reports/$reportType?$qs');
    final fileName = 'sifa_${reportType}_${_date(DateTime.now())}.$format';
    _browserDownload(bytes, fileName);
    return fileName;
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
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final bytes = await api.getBytes('/reports/customer-statement?$qs');
    final safe = customerName
        .replaceAll(RegExp(r'[^A-Za-z0-9ÇĞİÖŞÜçğıöşü]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final fileName = 'sifa_ekstre_${safe.isEmpty ? "musteri" : safe}_${_date(DateTime.now())}.xlsx';
    _browserDownload(bytes, fileName);
    return fileName;
  }

  void _browserDownload(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
""",
)

conditionalize(
    "diagnostics_download_service",
    """import 'dart:html' as html;

import 'api_client.dart';

class DiagnosticsDownloadService {
  DiagnosticsDownloadService({ApiClient? api}) : api = api ?? ApiClient();

  final ApiClient api;

  Future<String> download() async {
    final bytes = await api.getBytes('/admin/diagnostics-bundle');
    final now = DateTime.now();
    final stamp =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}';
    final fileName = 'sifa_diagnostics_$stamp.zip';
    final blob = html.Blob([bytes], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return fileName;
  }
}
""",
)

print("PWA compatibility layer prepared.")
