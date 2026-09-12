import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  ApiConfig._();

  static const _storageKey = 'sifa_api_base_url';
  static const _compiledBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String _baseUrl = '';

  static String get baseUrl => _baseUrl;

  static bool get configured => _baseUrl.trim().isNotEmpty;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey)?.trim() ?? '';
    final initial = saved.isNotEmpty ? saved : _compiledBaseUrl.trim();
    _baseUrl = _normalize(initial);
  }

  static Future<void> setBaseUrl(String value) async {
    final normalized = _normalize(value);
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.trim().isEmpty) {
      throw const FormatException(
        'Geçerli bir http/https sunucu adresi girin.',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, normalized);
    _baseUrl = normalized;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _baseUrl = '';
  }

  static String _normalize(String value) {
    var result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
