import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiClient {
  // Base URL (prod)
  static String API_BASE = 'https://celestya-backend.fly.dev';

  static final http.Client _client = http.Client();

  // Ajusta si quieres (15–25s suele ir bien)
  static const Duration _timeout = Duration(seconds: 20);

  // Debug: Store last error for UI inspection
  static Map<String, dynamic>? lastError;

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    bool isRetry = false,
    Map<String, String>? customHeaders,
  }) async {
    final String cleanPath = path.startsWith('/') ? path : '/$path';
    final Uri url = Uri.parse('$API_BASE$cleanPath');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    // Auth
    if (withAuth) {
      final authHeader = await AuthService.getAuthHeader();
      if (authHeader != null && authHeader.isNotEmpty) {
        headers['Authorization'] = authHeader;
      }
    }

    final String requestId = DateTime.now()
        .millisecondsSinceEpoch
        .toString()
        .substring(8); // Short ID

    if (kDebugMode) {
      debugPrint('[API] [$requestId] $method $cleanPath');
      debugPrint(
          '[API] [$requestId] Auth: ${headers.containsKey("Authorization") ? "present" : "none"}');
    }

    try {
      final String? bodyData = body != null ? jsonEncode(body) : null;
      late http.Response res;

      // START REQUEST
      if (method == 'POST') {
        if (kDebugMode && body != null) {
          debugPrint('[API] [$requestId] Payload: ${jsonEncode(body)}');
        }
        res = await _client
            .post(url, headers: headers, body: bodyData)
            .timeout(_timeout);
      } else if (method == 'PUT') {
        if (kDebugMode && body != null) {
          debugPrint('[API] [$requestId] Payload: ${jsonEncode(body)}');
        }
        res = await _client
            .put(url, headers: headers, body: bodyData)
            .timeout(_timeout);
      } else if (method == 'DELETE') {
        res = await _client
            .delete(url, headers: headers, body: bodyData)
            .timeout(_timeout);
      } else {
        res = await _client.get(url, headers: headers).timeout(_timeout);
      }

      if (kDebugMode) {
        debugPrint('[API] [$requestId] Status: ${res.statusCode}');
        debugPrint(
            '[API] [$requestId] Response: ${res.body.length > 500 ? "${res.body.substring(0, 500)}..." : res.body}');
      }

      // 401 Handing
      if (res.statusCode == 401 && withAuth && !isRetry) {
        if (kDebugMode) {
          debugPrint('[API] [$requestId] 401 Unauthorized. Retrying...');
        }
        final refreshed = await AuthService.tryAutoLogin();
        if (refreshed) {
          return _request(method, path,
              body: body, withAuth: withAuth, isRetry: true);
        }
      }

      // OK 204
      if (res.statusCode == 204 || res.body.trim().isEmpty) {
        if (res.statusCode >= 200 && res.statusCode < 300) return {'ok': true};
      }

      // SUCCESS JSON
      if (res.statusCode >= 200 && res.statusCode < 300) {
        try {
          return jsonDecode(res.body);
        } catch (_) {
          return {'ok': true, 'raw': res.body};
        }
      }

      // ERROR HANDLING (500, 4xx)
      String errorTitle = 'HTTP ${res.statusCode}';
      String errorDetail = res.body;
      bool isHtml =
          errorDetail.trim().toLowerCase().startsWith('<!doctype html') ||
              errorDetail.trim().toLowerCase().startsWith('<html');

      // Try parsing JSON error
      try {
        if (!isHtml) {
          final decoded = jsonDecode(errorDetail);
          if (decoded is Map) {
            final msg =
                decoded['detail'] ?? decoded['message'] ?? decoded['error'];
            if (msg != null) errorTitle += ': $msg';
          }
        }
      } catch (_) {}

      // LOGGING
      if (kDebugMode) {
        debugPrint('🛑 [API ERROR] [$requestId] Endpoint: $cleanPath');
        debugPrint('🛑 [API ERROR] Status: ${res.statusCode}');
        if (isHtml) {
          debugPrint(
              '🛑 [API ERROR] Type: HTML (Likely Nginx/Proxy/Fly.io Error)');
          debugPrint(
              '🛑 [API ERROR] Preview: ${errorDetail.substring(0, errorDetail.length > 200 ? 200 : errorDetail.length)}...');
        } else {
          debugPrint('🛑 [API ERROR] Type: JSON/Text');
          debugPrint('🛑 [API ERROR] Body: $errorDetail');
        }
      }

      // SAVE LAST ERROR (For Debug UI)
      lastError = {
        'requestId': requestId,
        'endpoint': cleanPath,
        'status': res.statusCode,
        'isHtml': isHtml,
        'body': errorDetail,
        'timestamp': DateTime.now().toIso8601String(),
      };

      throw Exception(errorTitle);
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('[API] [$requestId] ⏳ TIMEOUT: $e');
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('[API] [$requestId] 💥 EXCEPTION: $e');
      rethrow;
    }
  }

  static Future<dynamic> postJson(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) =>
      _request('POST', path, body: body, withAuth: withAuth);

  static Future<dynamic> putJson(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) =>
      _request('PUT', path, body: body, withAuth: withAuth);

  static Future<dynamic> getJson(
    String path, {
    bool withAuth = true,
    Map<String, String>? headers,
  }) =>
      _request('GET', path, withAuth: withAuth, customHeaders: headers);

  static Future<dynamic> deleteJson(
    String path, {
    Map<String, dynamic>? body,
    bool withAuth = true,
  }) =>
      _request('DELETE', path, body: body, withAuth: withAuth);

  static Future<void> deleteMyAccount() async {
    await deleteJson('/users/me', withAuth: true);
  }
}
