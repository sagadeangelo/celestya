import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/match_candidate.dart';
import 'api_client.dart';

class MatchesApi {
  // Store last debug info for UI diagnostics
  static Map<String, dynamic>? lastDebugInfo;

  /// GET /matches/suggested
  /// Backend actual regresa: {"matches": [ ...users... ]}
  /// Optional filters: maxDistanceKm, minAge, maxAge
  static Future<List<MatchCandidate>> getSuggested({
    int? maxDistanceKm,
    int? minAge,
    int? maxAge,
  }) async {
    try {
      // Build query params manually
      String path = 'matches/suggested';
      final params = <String>[];
      if (maxDistanceKm != null) {
        params.add('max_distance_km=$maxDistanceKm');
      }
      if (minAge != null) {
        params.add('min_age=$minAge');
      }
      if (maxAge != null) {
        params.add('max_age=$maxAge');
      }
      if (params.isNotEmpty) {
        path += '?${params.join('&')}';
      }

      debugPrint('[MatchesApi] GET $path');

      // Request with debug header if in debug mode
      final headers = kDebugMode ? {'X-Debug': '1'} : <String, String>{};
      final res = await ApiClient.getJson(path, headers: headers);

      // Reset debug info
      lastDebugInfo = null;

      // Frontend debug logs: response size, first item preview, list length
      try {
        final encoded = res == null
            ? 'null'
            : res is String
                ? res
                : jsonEncode(res);
        debugPrint('[MatchesApi] GET $path response_length=${encoded.length}');
      } catch (_) {}

      dynamic list;
      if (res is Map) {
        if (res['matches'] is List) {
          list = res['matches'];
        }
        // Capture debug info if present
        if (res['debug'] is Map) {
          lastDebugInfo = Map<String, dynamic>.from(res['debug']);
          if (kDebugMode) {
            debugPrint('[MatchesApi] Captured Debug Info: $lastDebugInfo');
            if (lastDebugInfo != null) {
              debugPrint(
                  '[MatchesApi] DB Path: ${lastDebugInfo!['db_path_guess']}');
              debugPrint(
                  '[MatchesApi] DB Sample: ${lastDebugInfo!['db_users_sample']}');
            }
          }
        }
      } else if (res is List) {
        list = res;
      } else {
        return [];
      }

      try {
        if (list is List && list.isNotEmpty) {
          debugPrint(
              '[MatchesApi] GET $path first_item_preview=${jsonEncode(list.first)}');
          debugPrint('[MatchesApi] GET $path raw_list_length=${list.length}');
        } else {
          debugPrint('[MatchesApi] GET $path raw_list_length=0');
        }
      } catch (_) {}

      final List<MatchCandidate> out = [];
      for (final e in (list as List)) {
        try {
          if (e is Map) {
            out.add(_fromBackendUser(Map<String, dynamic>.from(e)));
          }
        } catch (err) {
          debugPrint('[MatchesApi] parse item error: $err');
        }
      }
      debugPrint('[MatchesApi] GET $path parsed_count=${out.length}');
      return out;
    } catch (e) {
      debugPrint('[MatchesApi] Error getSuggested: $e');
      return [];
    }
  }

  /// Convierte el "User" del backend al MatchCandidate de tu UI.
  /// Como backend no tiene "name", usamos el prefijo del email o "Usuario".
  static MatchCandidate _fromBackendUser(Map<String, dynamic> u) {
    final int? idInt =
        (u['id'] is int) ? u['id'] as int : int.tryParse('${u['id']}');

    final String email = (u['email'] ?? '').toString();
    final String fallbackName = email.contains('@')
        ? email.split('@').first
        : (idInt != null ? 'Usuario $idInt' : 'Usuario');

    // Age: si viene birthdate "YYYY-MM-DD"
    int? age;
    final b = u['birthdate']?.toString();
    if (b != null && b.contains('-')) {
      try {
        final parts = b.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final d = int.parse(parts[2]);
        final now = DateTime.now();
        var a = now.year - y;
        final hadBirthday = (now.month > m) || (now.month == m && now.day >= d);
        if (!hadBirthday) a -= 1;
        if (a > 0 && a < 120) age = a;
      } catch (_) {}
    }

    // Foto: tu backend suele mandar photo_url o photoUrl dependiendo schema
    final photoUrl =
        (u['photo_url'] ?? u['photoUrl'] ?? u['photo'] ?? u['photoURL'])
            ?.toString();

    // Name sanitization
    String rawName =
        (u['name'] ?? u['display_name'] ?? fallbackName).toString();
    String cleanedName = rawName
        .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[,\\.\\s]+$'), '') // Remueve comas/puntos al final
        .replaceAll(
            RegExp(r'^[,\\.\\s]+'), '') // Remueve comas/puntos al inicio
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanedName.isEmpty || cleanedName.toLowerCase() == "null") {
      cleanedName = fallbackName;
    }

    return MatchCandidate(
      id: (idInt ?? 0).toString(),
      name: cleanedName,
      age: age,
      city: (u['city'] ?? '').toString(),
      bio: (u['bio'] ?? '').toString().isEmpty
          ? null
          : (u['bio'] ?? '').toString(),
      photoUrl: photoUrl,
      // Estos campos existen en tu DB:
      maritalStatus: u['marital_status']?.toString(),
      bodyType: u['body_type']?.toString(),
      hasChildren: u['has_children'] == null
          ? null
          : (u['has_children'] is bool
              ? (u['has_children'] as bool)
              : (u['has_children'].toString() == '1' ||
                  u['has_children'].toString().toLowerCase() == 'true')),
      // Si no tienes estos aún en backend, quedan nulos/default
      height: (u['height'] is num) ? (u['height'] as num).toDouble() : 0.0,
      exercise: u['exercise']?.toString() ?? 'Regular',
      interests: (u['interests'] is List)
          ? (u['interests'] as List).map((x) => x.toString()).toList()
          : const [],
      compatibility: (u['compatibility'] is num)
          ? (u['compatibility'] as num).toDouble()
          : 0.0,
      latitude: (u['lat'] is num) ? (u['lat'] as num).toDouble() : null,
      longitude: (u['lon'] is num) ? (u['lon'] as num).toDouble() : null,
      gender: u['gender']?.toString(), // Parse gender
      verificationStatus:
          (u['verification_status'] ?? u['verificationStatus'])?.toString(),
    );
  }

  /// GET /matches/confirmed
  /// Returns list of users with confirmed mutual matches
  static Future<List<MatchCandidate>> getConfirmed() async {
    try {
      final res = await ApiClient.getJson('matches/confirmed');
      if (res is! List) return [];

      // Parse same way as getSuggested
      return res
          .map((u) {
            if (u is! Map) return null;
            return _fromBackendUser(Map<String, dynamic>.from(u));
          })
          .whereType<MatchCandidate>()
          .toList();
    } catch (e) {
      debugPrint('[MatchesApi] Error getConfirmed: $e');
      return [];
    }
  }

  /// POST /matches/like/{userId}
  /// Returns {ok: true, matched: bool}
  static Future<Map<String, dynamic>> likeUser(String userId) async {
    try {
      final res = await ApiClient.postJson('matches/like/$userId', {});
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {'ok': false};
    } catch (e) {
      debugPrint('[MatchesApi] Error likeUser: $e');
      rethrow;
    }
  }

  /// POST /matches/pass/{userId}
  /// Returns {ok: true}
  static Future<bool> passUser(String userId) async {
    try {
      final res = await ApiClient.postJson('matches/pass/$userId', {});
      return res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('[MatchesApi] Error passUser: $e');
      return false;
    }
  }

  /// GET /users/{id}/profile
  /// Returns MatchCandidate for a specific user (for chat navigation)
  static Future<MatchCandidate?> getMatch(String userId) async {
    try {
      // Reusing Public Profile endpoint or similar.
      // If /users/{id}/profile exists and returns same schema as feed, we are good.
      // Otherwise we might need to use /users/{id} (admin) or adapting logic.
      // Assuming standard user profile endpoint:
      final res = await ApiClient.getJson('/users/$userId/profile');
      if (res is Map<String, dynamic>) {
        return _fromBackendUser(res);
      }
      return null;
    } catch (e) {
      debugPrint('[MatchesApi] Error getMatch($userId): $e');
      return null;
    }
  }

  /// POST /matches/unmatch/{userId}
  static Future<bool> unmatchUser(String userId) async {
    try {
      final res = await ApiClient.postJson('/matches/unmatch/$userId', {});
      return res is Map && res['ok'] == true;
    } catch (e) {
      debugPrint('[MatchesApi] Error unmatchUser: $e');
      return false;
    }
  }

  // Borrar todos los matches y reiniciar
  static Future<bool> resetMatches() async {
    try {
      // Prompt 1 & 4: Ensure it uses POST and correct path
      final response = await ApiClient.postJson('/matches/reset', {});
      return response is Map && response['ok'] == true;
    } catch (e) {
      debugPrint('[MatchesApi] Reset matches failed: $e');
      rethrow;
    }
  }
}
