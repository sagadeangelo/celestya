import 'package:flutter/foundation.dart';
import '../data/match_candidate.dart';
import 'api_client.dart';

class MatchesApi {
  /// GET /matches/suggested
  /// Backend actual regresa: {"matches": [ ...users... ]}
  static Future<List<MatchCandidate>> getSuggested() async {
    try {
      final res = await ApiClient.getJson('matches/suggested');

      dynamic list;
      if (res is Map && res['matches'] is List) {
        list = res['matches'];
      } else if (res is List) {
        list = res;
      } else {
        return [];
      }

      final List<MatchCandidate> out = [];
      for (final e in (list as List)) {
        if (e is Map) {
          out.add(_fromBackendUser(Map<String, dynamic>.from(e)));
        }
      }
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
    );
  }
}
