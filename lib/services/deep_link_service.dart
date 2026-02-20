import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static StreamSubscription<Uri>? _sub;
  static Function(String? email, String? token)? _onVerified;
  static Function(String token)? _onResetPassword;

  static final AppLinks _appLinks = AppLinks();

  /// Call once at app startup
  static Future<void> initialize({
    required Function(String? email, String? token) onVerified,
    required Function(String token) onResetPassword,
  }) async {
    _onVerified = onVerified;
    _onResetPassword = onResetPassword;
    await _initAppLinks();
  }

  static Future<void> _initAppLinks() async {
    // 1) App opened from a deep link (cold start)
    try {
      final Uri? initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLinkUri(initialUri);
      }
    } catch (_) {
      // ignore
    }

    // 2) Deep links while app is running (warm)
    _sub = _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleDeepLinkUri(uri),
      onError: (_) {
        // ignore
      },
    );
  }

  static void _handleDeepLinkUri(Uri uri) {
    // Handles:
    // celestya://verified?email=...&token=...
    // celestya://reset-password?token=...
    // celestya://auth/reset-password?token=... (Host: auth, Path: /reset-password)

    // 1. Verification
    if (uri.scheme == 'celestya' && uri.host == 'verified') {
      final email = uri.queryParameters['email'];
      final token = uri.queryParameters['token'];

      if (_onVerified != null) {
        _onVerified!(email, token);
      }
      return;
    }

    // 2. Reset Password
    bool isReset = false;
    if (uri.scheme == 'celestya') {
      if (uri.host == 'reset-password') {
        isReset = true;
      } else if ((uri.host == 'auth' || uri.host == '') &&
          uri.path == '/reset-password') {
        isReset = true;
      }
    }

    if (isReset) {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty && _onResetPassword != null) {
        _onResetPassword!(token);
      }
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _sub = null;
    _onVerified = null;
    _onResetPassword = null;
  }
}
