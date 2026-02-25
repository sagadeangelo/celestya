import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/auth_api.dart';

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
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);

    // Check if there's a pending verification first
    final prefs = await SharedPreferences.getInstance();
    final pendingEmail = prefs.getString(_keyPendingEmail);

    if (pendingEmail != null) {
      // User is in pending verification state
      state = AuthState.pendingVerification(pendingEmail);
      return;
    }

    // Otherwise, try auto-login
    final isLoggedIn = await AuthService.tryAutoLogin();
    if (isLoggedIn) {
      final token = await AuthService.getToken();
      state = AuthState.loggedIn(token ?? "");
    } else {
      state = AuthState.loggedOut();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await AuthApi.loginFull(email, password);
      final access = res['access_token'];
      final refresh = res['refresh_token'];
      await AuthService.saveTokens(access: access, refresh: refresh);
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
        // Store email temporarily for later verification
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyPendingEmail, email);

        state = AuthState.pendingVerification(email);
      } else if (res.containsKey('access_token')) {
        // Fallback: if backend returns token directly
        final access = res['access_token'];
        final refresh = res['refresh_token'] ?? "";
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
      // Backend returns directly the token dict: {"access_token": "...", ...}
      // It does NOT return "ok": true in this specific endpoint.
      if (res.containsKey('access_token')) {
        final access = res['access_token'];
        final refresh = res['refresh_token'];
        await AuthService.saveTokens(access: access, refresh: refresh);

        // Clear pending verification data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyPendingEmail);

        state = AuthState.loggedIn(access);
      } else {
        // Should not happen if ApiClient throws on error, but safekeeping
        state = state.copyWith(
            isLoading: false,
            errorMessage: res['message'] ?? 'Error desconocido');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Maneja el login vía Deep Link (Magic Link)
  Future<void> handleDeepLinkLogin(String? email, String? token) async {
    if (token == null || token.isEmpty) {
      // Si solo llega email (legacy o error), mostramos mensaje pero no podemos loguear sin password
      if (email != null) {
        state = AuthState.loggedOut(
            error: "Cuenta verificada. Por favor inicia sesión.");
      }
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      // Intercambiamos el link_token por un access_token real
      final res = await AuthApi.consumeVerifyLink(token);
      if (res['ok'] == true && res.containsKey('access_token')) {
        final access = res['access_token'];
        final refresh = res['refresh_token'] ?? "";
        await AuthService.saveTokens(access: access, refresh: refresh);

        // Limpiamos estado pendiente
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keyPendingEmail);

        state = AuthState.loggedIn(access);
      } else {
        state = AuthState.loggedOut(error: "Enlace inválido o expirado");
      }
    } catch (e) {
      state = AuthState.loggedOut(error: "Error al verificar enlace: $e");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingEmail);

    await AuthService.logout();
    state = AuthState.loggedOut();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
