import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static StreamSubscription<Uri>? _sub;
  static Function(String? email, String? token)? _onVerified;

  static final AppLinks _appLinks = AppLinks();

  /// Call once at app startup
  static Future<void> initialize(
      {required Function(String? email, String? token) onVerified}) async {
    _onVerified = onVerified;
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

    if (uri.scheme == 'celestya' && uri.host == 'verified') {
      final email = uri.queryParameters['email'];
      final token = uri.queryParameters['token'];

      if (_onVerified != null) {
        _onVerified!(email, token);
      }
    }
  }

  static Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _onVerified = null;
  }
}
