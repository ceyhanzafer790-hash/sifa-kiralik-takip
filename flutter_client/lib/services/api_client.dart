import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';
import 'app_version.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic data;
  final String? requestId;

  const ApiException({
    required this.statusCode,
    required this.message,
    this.data,
    this.requestId,
  });

  String? get code {
    final d = data;
    if (d is Map) {
      final detail = d['detail'];
      if (detail is Map && detail['code'] != null) {
        return detail['code'].toString();
      }
      if (d['code'] != null) return d['code'].toString();
    }
    return null;
  }

  dynamic get detail {
    final d = data;
    if (d is Map && d.containsKey('detail')) return d['detail'];
    return d;
  }

  String get userMessage {
    final base = switch (code) {
      'maintenance_mode' =>
        'Sistem bakım modunda. Yazma işlemleri geçici olarak kapalı.',
      'client_update_required' =>
        'Bu uygulama sürümü artık desteklenmiyor. Güncelleme gerekli.',
      'row_version_conflict' =>
        'Kayıt başka bir cihazda değiştirilmiş. Senkron çakışmasını çöz.',
      'operation_already_processed' =>
        'Bu işlem daha önce başarıyla işlendi.',
      'internal_error' =>
        'Sunucuda beklenmeyen bir hata oluştu. İşlem numarasını yöneticiye ilet.',
      _ => message,
    };

    if (requestId == null || requestId!.isEmpty) return base;
    return '$base\nİşlem No: $requestId';
  }

  @override
  String toString() => userMessage;
}

class ApiClient {
  ApiClient({AuthService? auth}) : auth = auth ?? AuthService();

  final AuthService auth;

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await auth.getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      'X-App-Version': AppVersion.current,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<dynamic> getJson(String path) async {
    final r = await http.get(uri(path), headers: await _headers());
    return _decode(r);
  }

  Future<Uint8List> getBytes(String path) async {
    final r = await http.get(
      uri(path),
      headers: await _headers(json: false),
    );

    if (r.statusCode < 200 || r.statusCode >= 300) {
      dynamic data;
      try {
        data = jsonDecode(r.body);
      } catch (_) {
        data = r.body;
      }

      final message = data is Map
          ? (data['detail'] ?? data['message'] ?? 'Sunucu hatası').toString()
          : 'Sunucu hatası (${r.statusCode})';

      throw ApiException(
        statusCode: r.statusCode,
        message: message,
        data: data,
        requestId: r.headers['x-request-id'],
      );
    }

    return r.bodyBytes;
  }

  Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final r = await http.post(
      uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(r);
  }

  Future<dynamic> patchJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final r = await http.patch(
      uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _decode(r);
  }

  dynamic _decode(http.Response response) {
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }

    if (!ok) {
      final message = data is Map
          ? (data['detail'] ?? data['message'] ?? 'Sunucu hatası').toString()
          : 'Sunucu hatası (${response.statusCode})';
      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        data: data,
        requestId: response.headers['x-request-id'],
      );
    }
    return data;
  }
}
