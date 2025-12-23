import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // ⚠️ Cambia esto a tu backend
  static const String API_BASE = 'http://127.0.0.1:8000';

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Uri _u(String path) => Uri.parse('$API_BASE$path');

  static Future<Map<String, dynamic>> postJson(String path, Map body, {bool withAuth = true}) async {
    final res = await http.post(_u(path), headers: await _headers(withAuth: withAuth), body: jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  static Future<Map<String, dynamic>> getJson(String path, {bool withAuth = true}) async {
    final res = await http.get(_u(path), headers: await _headers(withAuth: withAuth));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}
