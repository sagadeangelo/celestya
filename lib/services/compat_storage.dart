// lib/services/compat_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CompatStorage {
  static const _keyCompleted = 'compat_completed';
  static const _keyAnswers = 'compat_answers';

  /// Guarda las respuestas del cuestionario como JSON.
  static Future<void> saveAnswers(Map<String, dynamic> answers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCompleted, true);
    await prefs.setString(_keyAnswers, jsonEncode(answers));
  }

  /// Devuelve true si el cuestionario ya fue completado.
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCompleted) ?? false;
  }

  /// Carga las respuestas como un Map.
  static Future<Map<String, dynamic>?> loadAnswers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyAnswers);
    if (jsonStr == null) return null;
    return jsonDecode(jsonStr);
  }

  /// Elimina los datos del cuestionario (por si agregamos un botón de reset).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCompleted);
    await prefs.remove(_keyAnswers);
  }
}
