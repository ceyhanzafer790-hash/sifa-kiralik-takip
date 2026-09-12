import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'app_version.dart';

class DocumentApiService {
  DocumentApiService({AuthService? auth}) : auth = auth ?? AuthService();

  final AuthService auth;

  Future<void> pickAndUpload({
    required String rentalRecordId,
    required RentalDocumentType type,
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

    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    if (file.bytes == null) {
      throw StateError('Dosya belleğe okunamadı.');
    }

    final token = await auth.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/rentals/$rentalRecordId/documents',
      ),
    );

    request.headers['X-App-Version'] = AppVersion.current;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['document_type'] = _type(type);
    if (rentalMovementId != null) {
      request.fields['rental_movement_id'] = rentalMovementId;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Belge yüklenemedi.';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        message = (data['detail'] ?? message).toString();
      } catch (_) {}
      throw StateError(message);
    }
  }


  Future<void> uploadLocalFile({
    required String rentalRecordId,
    required String documentType,
    required String localPath,
    required String originalFileName,
    String? rentalMovementId,
  }) async {
    final token = await auth.getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}/rentals/$rentalRecordId/documents',
      ),
    );

    request.headers['X-App-Version'] = AppVersion.current;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['document_type'] = documentType;
    if (rentalMovementId != null) {
      request.fields['rental_movement_id'] = rentalMovementId;
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        localPath,
        filename: originalFileName,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Belge yüklenemedi.';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        message = (data['detail'] ?? message).toString();
      } catch (_) {}
      throw StateError(message);
    }
  }

  Future<void> openDocument(String documentId) async {
    final token = await auth.getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/documents/$documentId/url'),
      headers: {
        'X-App-Version': AppVersion.current,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw StateError('Belge açılamadı.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawUrl = data['url'].toString();
    final absoluteUrl = rawUrl.startsWith('http://') ||
            rawUrl.startsWith('https://')
        ? rawUrl
        : '${ApiConfig.baseUrl}$rawUrl';
    final url = Uri.parse(absoluteUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('Belge görüntüleyici açılamadı.');
    }
  }

  String _type(RentalDocumentType type) => switch (type) {
        RentalDocumentType.contract => 'contract',
        RentalDocumentType.outboundDelivery => 'outbound_delivery',
        RentalDocumentType.inboundDelivery => 'inbound_delivery',
        RentalDocumentType.invoice => 'invoice',
        RentalDocumentType.other => 'other',
      };
}
