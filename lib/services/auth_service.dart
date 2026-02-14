import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage.dart';
import 'dart:async';

class AuthService {
  // Cache en memoria para acceso instantáneo
  static String? _memToken;
  static const String _tokenType = 'Bearer';

  static Future<void> saveToken(String accessToken) async {
    // Sanitize
    String clean = accessToken.trim().replaceAll('"', '').replaceAll("'", "");
    if (clean.toLowerCase().startsWith('bearer ')) {
      clean = clean.substring(7).trim();
    }

    _memToken = clean;
    await TokenStorage.saveToken(clean);
  }

  static Future<bool> tryAutoLogin() async {
    // Solo verificamos si tenemos token.
    // La validación real ocurrirá cuando se haga la primera petición a la API.
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      _memToken = token;
      return true;
    }
    return false;
  }

  static Future<void> logout() async {
    await TokenStorage.deleteToken();
    _memToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Limpia otros datos no sensibles si los hay
  }

  static Future<String?> getAuthHeader() async {
    if (_memToken != null) {
      return '$_tokenType $_memToken';
    }

    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      _memToken = token;
      return '$_tokenType $token';
    }
    return null;
  }

  static Future<String?> getToken() async {
    if (_memToken != null) return _memToken;
    final token = await TokenStorage.getToken();
    if (token != null) {
      _memToken = token;
    }
    return _memToken;
  }
}
