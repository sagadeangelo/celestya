import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QuizLocalStorage {
  static const String _storageKey = 'celestya_quiz_progress';

  /// Guarda una respuesta individual de forma inmediata.
  /// Se guarda como un mapa JSON persistente.
  static Future<void> saveAnswer(String questionId, List<String> selectedOptions) async {
    final prefs = await SharedPreferences.getInstance();
    final currentAnswers = await loadAnswers();
    
    currentAnswers[questionId] = selectedOptions;
    
    await prefs.setString(_storageKey, jsonEncode(currentAnswers));
  }

  /// Carga todas las respuestas guardadas hasta el momento.
  static Future<Map<String, List<String>>> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> decoded = jsonDecode(jsonString);
      // Convertimos dynamic a List<String> para seguridad de tipos
      return decoded.map((key, value) => MapEntry(
            key,
            List<String>.from(value),
          ));
    } catch (e) {
      return {};
    }
  }

  /// Limpia el progreso del cuestionario (útil al finalizar o reiniciar).
  static Future<void> clearAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// (Opcional) Verifica si hay un cuestionario en curso.
  static Future<bool> hasProgress() async {
    final current = await loadAnswers();
    return current.isNotEmpty;
  }
}
