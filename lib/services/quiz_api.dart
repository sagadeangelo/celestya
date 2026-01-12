import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'auth_service.dart';

class QuizApi {
  /// Envía las respuestas del cuestionario al servidor.
  /// 
  /// Se asume que el backend espera un POST a `/users/me/quiz`
  /// con un body JSON: `{ "answers": { "q1": ["a1"], ... } }`
  static Future<void> saveQuizAnswers(Map<String, dynamic> answers) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('No hay sesión activa para guardar el cuestionario');
    }

    final url = Uri.parse('${ApiClient.API_BASE}/users/me/quiz');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "answers": answers
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al guardar respuestas: ${response.statusCode} ${response.body}');
    }
  }

  /// Recupera las respuestas guardadas (si se requiere en el futuro)
  static Future<Map<String, dynamic>?> getQuizAnswers() async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    final url = Uri.parse('${ApiClient.API_BASE}/users/me/quiz');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['answers'];
    }
    return null;
  }
}
