import 'package:shared_preferences/shared_preferences.dart';
import 'auth_api.dart';

class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyEmail = 'auth_email';
  static const String _keyPassword = 'auth_password'; // NOTE: In production use secure storage

  /// Guarda las credenciales y el token para inicio de sesión automático
  static Future<void> saveCredentials(String email, String password, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyEmail, email);
    await prefs.setString(_keyPassword, password);
  }

  /// Verifica si hay credenciales guardadas y válidas intentando hacer login
  /// Retorna true si el login automático fue exitoso
  static Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_keyEmail);
      final password = prefs.getString(_keyPassword);

      if (email == null || password == null) {
        return false;
      }

      // Intentamos hacer login de nuevo para obtener un token fresco
      final newToken = await AuthApi.login(email, password);
      
      // Si funciona, actualizamos el token
      await prefs.setString(_keyToken, newToken);
      return true;
    } catch (e) {
      // Si falla el login (ej. contraseña cambiada), limpiamos credenciales
      await clearCredentials();
      return false;
    }
  }

  /// Cierra sesión borrando todas las credenciales
  static Future<void> logout() async {
    await clearCredentials();
  }

  /// Limpia las credenciales almacenadas
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
  }

  /// Obtiene el token actual (si existe)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }
}
