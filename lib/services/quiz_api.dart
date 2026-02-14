import 'api_client.dart';

class QuizApi {
  /// Envía las respuestas del cuestionario. ApiClient maneja la renovación de sesión.
  static Future<void> saveQuizAnswers(Map<String, dynamic> answers) async {
    await ApiClient.postJson(
      '/users/me/quiz-answers',
      {"answers": answers},
      withAuth: true,
    );
  }

  /// Recupera las respuestas guardadas. ApiClient maneja la renovación de sesión.
  static Future<Map<String, dynamic>?> getQuizAnswers() async {
    try {
      final response = await ApiClient.getJson('/users/me/quiz-answers', withAuth: true);
      return response['answers'];
    } catch (e) {
       // El error ya fue reportado por ApiClient si fue 401
    }
    return null;
  }
}
