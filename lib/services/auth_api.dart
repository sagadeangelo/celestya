import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'dart:convert';

class AuthApi {
  /// Realiza login y retorna el objeto Token completo {"access_token": "...", "token_type": "bearer"}
  static Future<Map<String, dynamic>> loginFull(
      String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiClient.API_BASE}/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception('Login fallido (${res.statusCode}): ${res.body}');
  }

  /// Mantiene compatibilidad con el método viejo
  static Future<String> login(String email, String password) async {
    final data = await loginFull(email, password);
    return data['access_token'];
  }

  static Future<Map<String, dynamic>> registerRaw({
    required String email,
    required String password,
    required String birthdateIso,
    required String city,
    required String name,
  }) async {
    final payload = {
      'email': email,
      'password': password,
      'birthdate': birthdateIso,
      'city': city,
      'name': name,
    };
    return await ApiClient.postJson('/auth/register', payload, withAuth: false);
  }

  static Future<String> register({
    required String email,
    required String password,
    required String birthdateIso,
    required String city,
    required String name,
  }) async {
    final json = await registerRaw(
      email: email,
      password: password,
      birthdateIso: birthdateIso,
      city: city,
      name: name,
    );
    // Backward compatibility if it returns token directly (though we changed it)
    return json['access_token'] ?? "";
  }

  static Future<Map<String, dynamic>> verifyEmail(
      String email, String code) async {
    final payload = {'email': email, 'code': code};
    return await ApiClient.postJson('/auth/verify-email', payload,
        withAuth: false);
  }

  static Future<Map<String, dynamic>> resendVerification(String email) async {
    final payload = {'email': email};
    return await ApiClient.postJson('/auth/resend-verification', payload,
        withAuth: false);
  }

  static Future<Map<String, dynamic>> consumeVerifyLink(String token) async {
    return await ApiClient.postJson(
      '/auth/consume-verify-link',
      {'token': token},
      withAuth: false,
    );
  }
}
