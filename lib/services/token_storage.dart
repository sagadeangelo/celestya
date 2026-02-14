import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _keyAccessToken = 'auth_access_token';
  // We do NOT store password anymore as per new requirements
  // static const _keyPassword = 'auth_password';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyAccessToken, value: token);
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _keyAccessToken);
  }

  static Future<void> deleteAll() async {
    await _storage.deleteAll();
  }
}
