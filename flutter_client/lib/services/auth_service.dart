import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'app_version.dart';

class AuthService {
  static const _tokenKey = 'sifa_access_token';
  static const _userNameKey = 'sifa_user_name';
  static const _roleKey = 'sifa_user_role';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  Future<bool> canWrite() async {
    final role = await getRole();
    return role == 'admin' || role == 'staff';
  }

  Future<bool> hasSession() async => (await getToken())?.isNotEmpty == true;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (!ApiConfig.configured) {
      throw StateError('API_BASE_URL tanımlı değil.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'X-App-Version': AppVersion.current,
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final message = _message(response.body) ?? 'Giriş yapılamadı.';
      throw StateError(message);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Sunucu geçerli oturum anahtarı döndürmedi.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    final fullName = data['full_name'] as String?;
    if (fullName != null) {
      await prefs.setString(_userNameKey, fullName);
    }
    final role = data['role'] as String?;
    if (role != null) {
      await prefs.setString(_roleKey, role);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_roleKey);
  }

  String? _message(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return (data['detail'] ?? data['message'])?.toString();
    } catch (_) {
      return null;
    }
  }
}
