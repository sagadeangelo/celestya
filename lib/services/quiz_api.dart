import 'package:dio/dio.dart';
import 'api_client.dart';
import 'auth_service.dart';

class QuizApi {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiClient.API_BASE,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  /// Envía las respuestas del cuestionario al servidor usando Dio.
  static Future<void> saveQuizAnswers(Map<String, dynamic> answers) async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw Exception('No hay sesión activa para guardar el cuestionario');
    }

    try {
      final response = await _dio.post(
        '/users/me/quiz-answers', // Updated endpoint as per request
        data: {
          "answers": answers
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error: ${response.statusCode} ${response.data}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red: ${e.message}');
    }
  }

  /// Recupera las respuestas guardadas
  static Future<Map<String, dynamic>?> getQuizAnswers() async {
    final token = await AuthService.getToken();
    if (token == null) return null;

    try {
      final response = await _dio.get(
        '/users/me/quiz-answers',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['answers'];
      }
    } catch (_) {}
    return null;
  }
}
