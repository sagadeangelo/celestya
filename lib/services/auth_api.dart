import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthApi {
  static Future<String> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiClient.API_BASE}/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = RegExp(r'"access_token"\s*:\s*"([^"]+)"').firstMatch(res.body)?.group(1);
      if (token == null) {
        throw Exception('Respuesta sin token: ${res.body}');
      }
      return token;
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }

  static Future<String> register({
    required String email,
    required String password,
    required String birthdateIso, // yyyy-MM-dd
    required String city,
  }) async {
    final payload = {
      'email': email,
      'password': password,
      'birthdate': birthdateIso,
      'city': city,
    };
    final json = await ApiClient.postJson('/auth/register', payload, withAuth: false);
    final token = json['access_token'] as String?;
    if (token == null) throw Exception('Respuesta sin token');
    return token;
  }
}
