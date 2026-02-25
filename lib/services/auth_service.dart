import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage.dart';
import 'auth_api.dart';
import 'dart:async';

class AuthService {
  // Cache en memoria para acceso instantáneo
  static String? _memToken;
  static const String _tokenType = 'Bearer';

  static Future<void> saveTokens(
      {required String access, required String refresh}) async {
    // Sanitize
    String clean = access.trim().replaceAll('"', '').replaceAll("'", "");
    if (clean.toLowerCase().startsWith('bearer ')) {
      clean = clean.substring(7).trim();
    }

    _memToken = clean;
    await TokenStorage.saveTokens(access: clean, refresh: refresh);

    if (kDebugMode) {
      debugPrint('JWT SAVE SUCCESS (Access + Refresh)');
    }
  }

  static Future<bool> tryAutoLogin() async {
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _memToken = token;
      return true;
    }
    return false;
  }

  /// Tries to refresh the access token using the stored refresh token.
  /// Returns true if successful, false otherwise.
  static Future<bool> refreshSession() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        if (kDebugMode) debugPrint('[AuthService] No refresh token found.');
        return false;
      }

      if (kDebugMode) debugPrint('[AuthService] Attempting token refresh...');
      // Note: Implying AuthApi is already imported or available in scope.
      // Need to ensure AuthService can reach AuthApi without circular deps.
      final data = await AuthApi.refreshToken(refreshToken);

      if (data.containsKey('access_token') &&
          data.containsKey('refresh_token')) {
        await saveTokens(
          access: data['access_token'],
          refresh: data['refresh_token'],
        );
        if (kDebugMode)
          debugPrint('[AuthService] Token refreshed successfully.');
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthService] Refresh session failed: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await TokenStorage.deleteTokens();
    _memToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getAuthHeader() async {
    if (_memToken != null) {
      return '$_tokenType $_memToken';
    }

    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      _memToken = token;
      return '$_tokenType $token';
    }
    return null;
  }

  static Future<String?> getToken() async {
    if (_memToken != null) return _memToken;
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      _memToken = token;
    }
    return _memToken;
  }

  static Future<String?> getRefreshToken() async {
    return await TokenStorage.getRefreshToken();
  }
}
