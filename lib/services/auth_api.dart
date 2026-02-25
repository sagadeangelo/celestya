import 'api_client.dart';

class AuthApi {
  /// Realiza login y retorna el objeto Token completo {"access_token": "...", "token_type": "bearer"}
  static Future<Map<String, dynamic>> loginFull(String email, String password,
      {String? deviceId}) async {
    // Note: OAuth2 typically uses form-urlencoded but our backend supports JSON login too
    final payload = {
      'username': email,
      'password': password,
      if (deviceId != null) 'device_id': deviceId
    };

    final res =
        await ApiClient.postJson('/auth/login', payload, withAuth: false);
    return res as Map<String, dynamic>;
  }

  /// Mantiene compatibilidad con el método viejo
  static Future<String> login(String email, String password) async {
    final data = await loginFull(email, password);
    return data['access_token'];
  }

  static Future<Map<String, dynamic>> registerRaw({
    required String email,
    required String password,
    required String birthdateIso,
    required String city,
    required String name,
  }) async {
    final payload = {
      'email': email,
      'password': password,
      'birthdate': birthdateIso,
      'city': city,
      'name': name,
    };
    return await ApiClient.postJson('/auth/register', payload, withAuth: false);
  }

  static Future<String> register({
    required String email,
    required String password,
    required String birthdateIso,
    required String city,
    required String name,
  }) async {
    final json = await registerRaw(
      email: email,
      password: password,
      birthdateIso: birthdateIso,
      city: city,
      name: name,
    );
    // Backward compatibility if it returns token directly (though we changed it)
    return json['access_token'] ?? "";
  }

  static Future<Map<String, dynamic>> verifyEmail(
      String email, String code) async {
    final payload = {'email': email, 'code': code};
    return await ApiClient.postJson('/auth/verify-email', payload,
        withAuth: false);
  }

  static Future<Map<String, dynamic>> resendVerification(String email) async {
    final payload = {'email': email};
    return await ApiClient.postJson('/auth/resend-verification', payload,
        withAuth: false);
  }

  static Future<Map<String, dynamic>> consumeVerifyLink(String token) async {
    return await ApiClient.postJson(
      '/auth/consume-verify-link',
      {'token': token},
      withAuth: false,
    );
  }

  static Future<void> forgotPassword(String email) async {
    await ApiClient.postJson(
      '/auth/forgot-password',
      {'email': email},
      withAuth: false,
    );
  }

  static Future<void> resetPassword(String token, String newPassword) async {
    await ApiClient.postJson(
      '/auth/reset-password',
      {'token': token, 'new_password': newPassword},
      withAuth: false,
    );
  }

  static Future<Map<String, dynamic>> refreshToken(String refreshToken,
      {String? deviceId}) async {
    return await ApiClient.postJson(
      '/auth/refresh',
      {
        'refresh_token': refreshToken,
        if (deviceId != null) 'device_id': deviceId
      },
      withAuth: false,
    );
  }
}
