// lib/services/api_client.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ApiClient {
  static String API_BASE = 'https://celestya-backend.fly.dev';

  // ── Refresh-lock ────────────────────────────────────────────────────────────
  // While a refresh is in-flight every concurrent 401 waits for the same
  // Completer instead of triggering a second /auth/refresh call.
  static Completer<bool>? _refreshCompleter;

  // ── Force-logout callback ────────────────────────────────────────────────────
  // Set once in AuthNotifier's constructor. The interceptor calls this when
  // the refresh token is definitively invalid (REFRESH_* codes or 401/403 on
  // the refresh endpoint itself). No UI layer needs to catch SESSION_LOST.
  static VoidCallback? onForceLogout;

  // ── Dio instance ─────────────────────────────────────────────────────────────
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
        'X-Client': 'mobile',
      },
    ));

    // Force HTTPS in non-localhost environments
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
        responseHeader: false,
        responseBody: true,
        error: true,
      ));
    }

    dio.interceptors.add(InterceptorsWrapper(
      // ── Attach Authorization header ──────────────────────────────────────────
      onRequest: (options, handler) async {
        if (options.extra['withAuth'] != false) {
          final authHeader = await AuthService.getAuthHeader();
          if (authHeader != null) {
            options.headers['Authorization'] = authHeader;
          }
        }
        return handler.next(options);
      },

      // ── Global error handler ─────────────────────────────────────────────────
      onError: (DioException e, handler) async {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        final String? errorCode =
            (responseData is Map) ? responseData['code'] as String? : null;

        // ── Case 1: Access token expired → silent refresh + retry ──────────────
        if (statusCode == 401 && errorCode == 'ACCESS_EXPIRED') {
          if (kDebugMode) {
            debugPrint(
                '[REFRESH] Access token expired. Acquiring refresh lock…');
          }

          bool refreshed = false;

          if (_refreshCompleter != null) {
            // Another refresh is already in-flight — wait for it.
            if (kDebugMode) {
              debugPrint('[REFRESH] Waiting for in-flight refresh…');
            }
            refreshed = await _refreshCompleter!.future;
          } else {
            // We are the first — drive the refresh.
            _refreshCompleter = Completer<bool>();
            try {
              refreshed = await AuthService.refreshSession();
              if (kDebugMode) {
                debugPrint(
                    '[REFRESH] Result: ${refreshed ? "OK ✅" : "FAILED ❌"}');
              }
              _refreshCompleter!.complete(refreshed);
            } catch (refreshErr) {
              if (kDebugMode) {
                debugPrint('[REFRESH] Exception during refresh: $refreshErr');
              }
              _refreshCompleter!.complete(false);
              refreshed = false;
            } finally {
              _refreshCompleter = null;
            }
          }

          if (refreshed) {
            // Retry the original request with the new token.
            final opts = e.requestOptions;
            final newAuthHeader = await AuthService.getAuthHeader();
            if (newAuthHeader != null) {
              opts.headers['Authorization'] = newAuthHeader;
            }
            try {
              final retried = await _dio.request(
                opts.path,
                options: Options(
                  method: opts.method,
                  headers: opts.headers,
                  extra: opts.extra,
                ),
                data: opts.data,
                queryParameters: opts.queryParameters,
              );
              if (kDebugMode) {
                debugPrint('[REFRESH] Retry succeeded ✅ → ${opts.path}');
              }
              return handler.resolve(retried);
            } catch (retryErr) {
              if (kDebugMode) {
                debugPrint('[REFRESH] Retry after refresh failed: $retryErr');
              }
              return handler.next(e);
            }
          }

          // Refresh failed but we already fell through — pass error downstream.
          // The definitive logout is triggered by Case 2 below (REFRESH_* code).
          return handler.next(e);
        }

        // ── Case 2: Refresh token definitively invalid → force logout ──────────
        // This covers:
        //   • 401/403 coming from the /auth/refresh endpoint itself
        //     (backend sets code = REFRESH_EXPIRED | REFRESH_REUSED | etc.)
        //   • Any 401/403 on a non-ACCESS_EXPIRED path that has a REFRESH_ code
        if ((statusCode == 401 || statusCode == 403) &&
            errorCode != null &&
            errorCode.startsWith('REFRESH_')) {
          if (kDebugMode) {
            debugPrint(
                '[LOGOUT] Definitive refresh failure ($errorCode). Forcing logout.');
          }
          onForceLogout?.call();
          return handler.reject(DioException(
            requestOptions: e.requestOptions,
            error: 'SESSION_EXPIRED',
            type: DioExceptionType.cancel,
          ));
        }

        // ── Case 3: Network error / timeout / 5xx → NO logout ─────────────────
        // Just propagate. The UI shows an offline banner; the session is kept.
        if (kDebugMode) {
          debugPrint(
              '[API] Non-auth error (${e.type}, $statusCode}) — no logout.');
        }
        return handler.next(e);
      },
    ));

    return dio;
  }

  // ── Internal request wrapper ──────────────────────────────────────────────────
  static Future<dynamic> _request(
    String method,
    String path, {
    dynamic body,
    bool withAuth = true,
    Map<String, String>? customHeaders,
  }) async {
    final String cleanPath = path.startsWith('/') ? path : '/$path';

    if (kDebugMode) {
      debugPrint('🚀 [API REQ] $method $cleanPath');
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
        debugPrint('✅ [API RES] $method $cleanPath → ${response.statusCode}');
      }

      return response.data;
    } on DioException catch (e) {
      // SESSION_EXPIRED is already handled by the interceptor (force logout +
      // reject). Surface it as a plain exception so callers don't need special
      // handling — they will simply see a failed request.
      if (e.error == 'SESSION_EXPIRED') {
        throw Exception('SESSION_EXPIRED');
      }

      String errorMsg = 'Error en la petición';
      final int? statusCode = e.response?.statusCode;
      final dynamic responseData = e.response?.data;

      if (responseData is Map) {
        errorMsg =
            responseData['detail'] ?? responseData['message'] ?? e.message;
      }

      if (kDebugMode) {
        debugPrint('🛑 [API ERR] $method $cleanPath → $statusCode');
        debugPrint('🛑 [API ERR] Detail: $errorMsg');
        debugPrint('🛑 [API ERR] Full Data: $responseData');
      }

      final statusStr = statusCode?.toString() ?? 'Timeout/Network';
      throw Exception('[$statusStr] $errorMsg');
    }
  }

  // ── Public HTTP helpers ───────────────────────────────────────────────────────
  static Future<dynamic> postJson(String path, dynamic body,
          {bool withAuth = true, Map<String, String>? headers}) =>
      _request('POST', path,
          body: body, withAuth: withAuth, customHeaders: headers);

  static Future<dynamic> putJson(String path, dynamic body,
          {bool withAuth = true, Map<String, String>? headers}) =>
      _request('PUT', path,
          body: body, withAuth: withAuth, customHeaders: headers);

  static Future<dynamic> patchJson(String path, dynamic body,
          {bool withAuth = true, Map<String, String>? headers}) =>
      _request('PATCH', path,
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

  // ── Connectivity diagnostic ───────────────────────────────────────────────────
  static Future<Map<String, dynamic>> checkConnectivity() async {
    final startTime = DateTime.now();
    if (kDebugMode) {
      debugPrint('🔍 [DIAG] Checking connectivity via /health…');
    }

    try {
      final response = await _dio.get('/health');
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        debugPrint('✅ [DIAG] Server reached in ${duration}ms');
      }

      return {
        'ok': true,
        'ms': duration,
        'data': response.data,
      };
    } on DioException catch (e) {
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (kDebugMode) {
        debugPrint('🛑 [DIAG] Connectivity error after ${duration}ms');
        debugPrint('🛑 [DIAG] Type: ${e.type}');
        debugPrint('🛑 [DIAG] Message: ${e.message}');
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
