// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';

enum AuthStatus { loggedOut, pendingVerification, loggedIn }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? token;
  final String? errorMessage;
  final bool isLoading;

  AuthState({
    required this.status,
    this.email,
    this.token,
    this.errorMessage,
    this.isLoading = false,
  });

  factory AuthState.loggedOut({String? error}) => AuthState(
        status: AuthStatus.loggedOut,
        errorMessage: error,
      );

  factory AuthState.pendingVerification(String email) => AuthState(
        status: AuthStatus.pendingVerification,
        email: email,
      );

  factory AuthState.loggedIn(String token) => AuthState(
        status: AuthStatus.loggedIn,
        token: token,
      );

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? token,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  static const String _keyPendingEmail = 'pending_verification_email';

  AuthNotifier() : super(AuthState.loggedOut()) {
    // Register the force-logout callback so the Dio interceptor can drive
    // auth state changes without touching any UI layer.
    ApiClient.onForceLogout = () {
      if (kDebugMode) {
        debugPrint('[LOGOUT] onForceLogout triggered by interceptor.');
      }
      _doLogout();
    };

    _init();
  }

  // ── Bootstrap / session hydration ───────────────────────────────────────────
  Future<void> _init() async {
    state = state.copyWith(isLoading: true);

    // ── Step 0: Check pending email verification (takes priority) ────────────
    final prefs = await SharedPreferences.getInstance();
    final pendingEmail = prefs.getString(_keyPendingEmail);
    if (pendingEmail != null) {
      if (kDebugMode) {
        debugPrint(
            '[BOOT] Pending verification for $pendingEmail — showing verify screen.');
      }
      state = AuthState.pendingVerification(pendingEmail);
      return;
    }

    // ── Step 1: Read tokens from secure storage ───────────────────────────────
    final accessToken = await TokenStorage.getAccessToken();
    final refreshToken = await TokenStorage.getRefreshToken();
    final hasTokens = accessToken != null && accessToken.isNotEmpty;
    final hasRefresh = refreshToken != null && refreshToken.isNotEmpty;

    if (kDebugMode) {
      final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
      debugPrint(
          '[BOOT] accessToken present: $hasTokens | refreshToken present: $hasRefresh | onboarding_completed: $onboardingDone');
    }

    if (!hasTokens) {
      if (kDebugMode) debugPrint('[BOOT] No token found → loggedOut');
      state = AuthState.loggedOut();
      return;
    }

    // ── Step 2: Verify session with /users/me ─────────────────────────────────
    await _verifySession(accessToken);
  }

  /// Calls /users/me to confirm the session is alive.
  /// - 200           → loggedIn
  /// - 401 ACCESS_EXPIRED → try silent refresh → retry /me
  /// - Network/5xx   → keep loggedIn (offline mode, interceptor handles later)
  /// - Definitive 401/403 with REFRESH_* → loggedOut
  Future<void> _verifySession(String token) async {
    if (kDebugMode) debugPrint('[BOOT] Calling /users/me to verify session…');

    try {
      // The Dio interceptor automatically handles ACCESS_EXPIRED 401 by
      // refreshing and retrying. If it resolves here, the session is valid.
      await ApiClient.getJson('/users/me', withAuth: true);

      if (kDebugMode) debugPrint('[BOOT] /users/me OK → loggedIn ✅');
      state = AuthState.loggedIn(token);
    } on Exception catch (e) {
      final msg = e.toString();

      if (msg.contains('SESSION_EXPIRED')) {
        // Interceptor already called onForceLogout → state already set to
        // loggedOut inside _doLogout(). Nothing more to do here.
        if (kDebugMode) {
          debugPrint(
              '[BOOT] /users/me → SESSION_EXPIRED (refresh failed definitively)');
        }
        return;
      }

      // Network / timeout / 5xx: keep the user logged in.
      // The banner in AuthGate will show the offline indicator.
      if (kDebugMode) {
        debugPrint(
            '[BOOT] /users/me failed with network/server error — keeping loggedIn (offline mode). Detail: $msg');
      }
      state = AuthState.loggedIn(token);
    }
  }

  // ── Internal logout (shared by manual logout + interceptor callback) ─────────
  Future<void> _doLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingEmail);
    await AuthService.logout(); // clears tokens, preserves onboarding_completed
    state = AuthState.loggedOut();
  }

  // ── Public actions ────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await AuthApi.loginFull(email, password);
      final access = res['access_token'];
      final refresh = res['refresh_token'];
      await AuthService.saveTokens(access: access, refresh: refresh);
      if (kDebugMode) debugPrint('[AUTH] Login successful.');
      state = AuthState.loggedIn(access);
    } catch (e) {
      state = AuthState.loggedOut(error: e.toString());
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String birthdateIso,
    required String city,
    required String name,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await AuthApi.registerRaw(
        email: email,
        password: password,
        birthdateIso: birthdateIso,
        city: city,
        name: name,
      );

      if (res['status'] == 'pending_verification') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyPendingEmail, email);
        state = AuthState.pendingVerification(email);
      } else if (res.containsKey('access_token')) {
        final access = res['access_token'];
        final refresh = res['refresh_token'] ?? '';
        await AuthService.saveTokens(access: access, refresh: refresh);
        state = AuthState.loggedIn(access);
      }
    } catch (e) {
      state = AuthState.loggedOut(error: e.toString());
    }
  }

  Future<void> verifyCode(String code) async {
    if (state.email == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await AuthApi.verifyEmail(state.email!, code);
      if (res.containsKey('access_token')) {
        final access = res['access_token'];
        final refresh = res['refresh_token'];
        await AuthService.saveTokens(access: access, refresh: refresh);

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyPendingEmail);

        state = AuthState.loggedIn(access);
      } else {
        state = state.copyWith(
            isLoading: false,
            errorMessage: res['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Handles login via Magic Link / Deep Link.
  Future<void> handleDeepLinkLogin(String? email, String? token) async {
    if (token == null || token.isEmpty) {
      if (email != null) {
        state = AuthState.loggedOut(
            error: 'Cuenta verificada. Por favor inicia sesión.');
      }
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      final res = await AuthApi.consumeVerifyLink(token);
      if (res['ok'] == true && res.containsKey('access_token')) {
        final access = res['access_token'];
        final refresh = res['refresh_token'] ?? '';
        await AuthService.saveTokens(access: access, refresh: refresh);

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyPendingEmail);

        state = AuthState.loggedIn(access);
      } else {
        state = AuthState.loggedOut(error: 'Enlace inválido o expirado');
      }
    } catch (e) {
      state = AuthState.loggedOut(error: 'Error al verificar enlace: $e');
    }
  }

  /// Public logout — the ONLY place that intentionally clears a session.
  Future<void> logout() async {
    if (kDebugMode) debugPrint('[LOGOUT] Manual logout triggered by user.');
    await _doLogout();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
