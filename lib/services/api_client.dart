import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ApiClient {
  static String API_BASE = 'https://celestya-backend.fly.dev';

  static final Dio _dio = _initDio();

  static Dio _initDio() {
    final dio = Dio(BaseOptions(
      baseUrl: API_BASE,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Client': 'mobile', // Para identificar tráfico en logs backend
      },
    ));

    // Force HTTPS if not present in production-like environment (or always as defensive)
    if (!API_BASE.startsWith('https://') && !API_BASE.contains('localhost')) {
      final newBase = API_BASE.replaceFirst('http://', 'https://');
      if (kDebugMode) debugPrint('[API] Forcing HTTPS: $API_BASE -> $newBase');
      dio.options.baseUrl = newBase;
    }

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
      ));
    }

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Automatically add Authorization header unless specifically excluded
        if (options.extra['withAuth'] != false) {
          final authHeader = await AuthService.getAuthHeader();
          if (authHeader != null) {
            options.headers['Authorization'] = authHeader;
          }
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        // ✅ Prompt 8: Handle 401 and Refresh Logic
        if (e.response?.statusCode == 401) {
          final responseData = e.response?.data;
          final String? errorCode =
              (responseData is Map) ? responseData['code'] : null;

          // SOLO intenta refresh si el código es ACCESS_EXPIRED
          if (errorCode == 'ACCESS_EXPIRED') {
            if (kDebugMode)
              debugPrint('[API] Token expired. Attempting refresh...');

            try {
              final refreshed = await AuthService.refreshSession();
              if (refreshed) {
                // Retry the original request
                final options = e.requestOptions;
                // Update headers with new token
                final newAuthHeader = await AuthService.getAuthHeader();
                if (newAuthHeader != null) {
                  options.headers['Authorization'] = newAuthHeader;
                }

                final clonedRequest = await _dio.request(
                  options.path,
                  options: Options(
                    method: options.method,
                    headers: options.headers,
                    extra: options.extra,
                  ),
                  data: options.data,
                  queryParameters: options.queryParameters,
                );
                return handler.resolve(clonedRequest);
              }
            } catch (refreshErr) {
              if (kDebugMode) debugPrint('[API] Refresh failed: $refreshErr');
            }

            // Si falla el refresh o no se pudo hacer, logout
            await AuthService.logout();
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              error: 'SESSION_LOST',
              type: DioExceptionType.cancel,
            ));
          }

          // Si es un error de REFRESH (REFRESH_REUSED, REFRESH_EXPIRED, etc)
          if (errorCode != null && errorCode.startsWith('REFRESH_')) {
            if (kDebugMode)
              debugPrint('[API] Permanent Refresh Error: $errorCode');
            await AuthService.logout();
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              error: 'SESSION_LOST',
              type: DioExceptionType.cancel,
            ));
          }
        }
        return handler.next(e);
      },
    ));

    return dio;
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    dynamic body,
    bool withAuth = true,
    Map<String, String>? customHeaders,
  }) async {
    // Ensure path starts with / to avoid joining issues with baseUrl
    final String cleanPath = path.startsWith('/') ? path : '/$path';

    if (kDebugMode) {
      debugPrint('🚀 [API REQ] $method $cleanPath');
      debugPrint('   BaseURL: $API_BASE');
      debugPrint('   Headers: $customHeaders (withAuth: $withAuth)');
      debugPrint('   Body: $body');
    }

    try {
      final response = await _dio.request(
        cleanPath,
        data: body,
        options: Options(
          method: method,
          headers: customHeaders,
          extra: {'withAuth': withAuth},
        ),
      );

      if (kDebugMode) {
        debugPrint('✅ [API RES] $method $cleanPath -> ${response.statusCode}');
        // debugPrint('✅ [API RES] Body: ${response.data}'); // Optional: too verbose?
      }

      return response.data;
    } on DioException catch (e) {
      if (e.error == 'SESSION_LOST') {
        throw Exception('SESSION_LOST');
      }

      String errorMsg = 'Error en la petición';
      int? statusCode = e.response?.statusCode;
      dynamic responseData = e.response?.data;

      if (responseData is Map) {
        errorMsg =
            responseData['detail'] ?? responseData['message'] ?? e.message;
      }

      if (kDebugMode) {
        debugPrint('🛑 [API ERR] $method $cleanPath -> $statusCode');
        debugPrint('🛑 [API ERR] Detail: $errorMsg');
        debugPrint('🛑 [API ERR] Full Data: $responseData');
      }

      // Re-wrap to include status code for better UI feedback (Prompt 2)
      final statusStr = statusCode?.toString() ?? 'Timeout/Network';
      throw Exception('[$statusStr] $errorMsg');
    }
  }

  static Future<dynamic> postJson(String path, dynamic body,
          {bool withAuth = true, Map<String, String>? headers}) =>
      _request('POST', path,
          body: body, withAuth: withAuth, customHeaders: headers);

  static Future<dynamic> putJson(String path, dynamic body,
          {bool withAuth = true, Map<String, String>? headers}) =>
      _request('PUT', path,
          body: body, withAuth: withAuth, customHeaders: headers);

  static Future<dynamic> getJson(String path,
          {bool withAuth = true, Map<String, String>? headers}) =>
      _request('GET', path, withAuth: withAuth, customHeaders: headers);

  static Future<dynamic> deleteJson(String path,
          {dynamic body, bool withAuth = true, Map<String, String>? headers}) =>
      _request('DELETE', path,
          body: body, withAuth: withAuth, customHeaders: headers);

  static Future<void> deleteMyAccount() async {
    await deleteJson('/users/me', withAuth: true);
  }

  /// ✅ Diagnóstico de conectividad
  static Future<Map<String, dynamic>> checkConnectivity() async {
    final startTime = DateTime.now();
    if (kDebugMode)
      debugPrint('🔍 [DIAG] Iniciando checkConnectivity a /health...');

    try {
      final response = await _dio.get('/health');
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        debugPrint('✅ [DIAG] Servidor alcanzado en ${duration}ms');
        debugPrint('✅ [DIAG] Respuesta: ${response.data}');
      }

      return {
        'ok': true,
        'ms': duration,
        'data': response.data,
      };
    } on DioException catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        debugPrint('🛑 [DIAG] Error de conectividad tras ${duration}ms');
        debugPrint('🛑 [DIAG] BASE_URL: ${API_BASE}');
        debugPrint('🛑 [DIAG] Type: ${e.type}');
        debugPrint('🛑 [DIAG] Message: ${e.message}');
        debugPrint('🛑 [DIAG] Error: ${e.error}');
        debugPrint('🛑 [DIAG] URI: ${e.requestOptions.uri}');
        debugPrint('🛑 [DIAG] Headers: ${e.requestOptions.headers}');
      }

      return {
        'ok': false,
        'ms': duration,
        'type': e.type.toString(),
        'message': e.message,
        'error': e.error.toString(),
      };
    } catch (e) {
      return {
        'ok': false,
        'error': e.toString(),
      };
    }
  }
}
