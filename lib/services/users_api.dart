import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';
import 'auth_service.dart';
import '../data/user_profile.dart'; // Added

class Me {
  final int id;
  final String email;
  final String? photoUrl;
  Me({required this.id, required this.email, this.photoUrl});

  factory Me.fromJson(Map<String, dynamic> j) => Me(
      id: j['id'] as int,
      email: j['email'] as String,
      photoUrl: j['photo_url'] as String?);
}

class UsersApi {
  /// Obtiene info del usuario actual. ApiClient maneja la auto-recuperación.
  static Future<Me> me() async {
    final json = await ApiClient.getJson('/users/me', withAuth: true);
    return Me.fromJson(json);
  }

  /// Sube una foto de perfil usando el nuevo flujo R2.
  /// 1. Sube el archivo a /upload (R2).
  /// 2. Guarda la 'key' resultante en el perfil del usuario llamando a /users/me/photo-key.
  static Future<String> uploadPhoto(File file) async {
    final token = await AuthService.getToken();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiClient.API_BASE}/upload'));

    if (token != null) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    req.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: file.uri.pathSegments.last,
      contentType: MediaType('image', _extToSubtype(file.path)),
    ));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (kDebugMode) {
      debugPrint('[UsersApi] uploadPhoto Status: ${res.statusCode}');
      debugPrint('[UsersApi] uploadPhoto Response: $body');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(body);
      final key = decoded['key'] as String;
      return key;
    }
    throw Exception('Error al subir foto (${res.statusCode}): $body');
  }

  static String _extToSubtype(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'jpeg';
    if (p.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }

  static Future<void> deleteAccount() async {
    await ApiClient.deleteJson('/users/me', withAuth: true);
  }

  /// Actualiza el perfil del usuario en el backend
  /// Sube la foto y la guarda en el perfil del usuario inmediatamente.
  /// PROMPT 2 - Implementación consolidada.
  static Future<String> uploadAndSaveProfilePhoto(File image) async {
    try {
      debugPrint(
          '[UsersApi] Iniciando uploadAndSaveProfilePhoto para: ${image.path}');
      final size = await image.length();
      debugPrint('[UsersApi] Tamaño del archivo: $size bytes');

      // 1. Upload a R2
      final key = await uploadPhoto(image);
      debugPrint('[UsersApi] Upload exitoso. Key: $key');

      // 2. Persistir en el perfil
      await ApiClient.putJson(
          '/users/me',
          {
            'profile_photo_key': key,
          },
          withAuth: true);
      debugPrint('[UsersApi] Key persistida en el perfil correctamente.');

      return key;
    } catch (e) {
      debugPrint('[UsersApi] Error en uploadAndSaveProfilePhoto: $e');
      rethrow;
    }
  }

  // ----------------------------
  // Identity Verification
  // ----------------------------

  /// Inicia una solicitud de verificación. Retorna {verificationId, instruction, status, attempt}
  static Future<Map<String, dynamic>> requestVerification() async {
    return await ApiClient.postJson('/verification/request', {},
        withAuth: true);
  }

  /// Sube la imagen para una solicitud específica.
  static Future<void> uploadVerificationImage(
      int verificationId, File image) async {
    final token = await AuthService.getToken();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiClient.API_BASE}/verification/upload'));

    if (token != null) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    // El backend espera verification_id como Form o field
    req.fields['verification_id'] = verificationId.toString();

    req.files.add(await http.MultipartFile.fromPath(
      'file',
      image.path,
      filename: 'verification.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    final res = await req.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          'Error al subir imagen de verificación (${res.statusCode}): $body');
    }
  }

  /// Obtiene el estado actual de la última verificación (incluyendo instrucción/razón)
  static Future<Map<String, dynamic>> getMyVerificationStatus() async {
    return await ApiClient.getJson('/verification/me', withAuth: true);
  }

  static Future<void> updateProfile(UserProfile profile) async {
    final payload = profile.toJson();
    // profile.toJson() already includes name and birthdate (YYYY-MM-DD string)

    await ApiClient.putJson(
      '/users/me',
      payload,
      withAuth: true,
    );
  }

  /// PROMPT 2 & 4 - Fotos adicionales (Galería)
  static Future<bool> uploadAndAddGalleryPhoto(File image) async {
    // 1. Upload to R2 (generic upload)
    final token = await AuthService.getToken();
    final req = http.MultipartRequest(
        'POST', Uri.parse('${ApiClient.API_BASE}/upload'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';

    req.files.add(await http.MultipartFile.fromPath(
      'file',
      image.path,
      contentType: MediaType('image', _extToSubtype(image.path)),
    ));

    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Error al subir a galería: $body');
    }

    final decoded = jsonDecode(body);
    final key = decoded['key'] as String;

    // 2. Append to gallery in backend
    await ApiClient.postJson('/users/me/gallery', {'profile_photo_key': key},
        withAuth: true);
    return true;
  }

  static Future<bool> removeGalleryPhoto(String key) async {
    await ApiClient.deleteJson('/users/me/gallery?key=$key', withAuth: true);
    return true;
  }

  /// Refresca la información del perfil desde el backend
  static Future<UserProfile?> getProfile() async {
    try {
      final json = await ApiClient.getJson('/users/me', withAuth: true);
      return UserProfile.fromJson(json);
    } catch (e) {
      debugPrint('[UsersApi] Error fetching profile: $e');
      return null;
    }
  }

  static Future<UserProfile> fetchMe() async {
    final json = await ApiClient.getJson('/users/me', withAuth: true);
    return UserProfile.fromJson(json);
  }

  /// Cambia el idioma en el backend
  static Future<void> setMyLanguage(String lang) async {
    await ApiClient.patchJson(
      '/users/me/language',
      {'language': lang},
      withAuth: true,
    );
  }

  // --- BATCH SIGNED URLS & CACHE ---
  static final Map<String, String> _signedUrlCache = {};

  static Future<Map<String, String>> fetchSignedUrlsBatch(
      List<String> keys) async {
    final keysToFetch =
        keys.where((k) => !_signedUrlCache.containsKey(k)).toList();
    if (keysToFetch.isEmpty) {
      return Map.fromEntries(keys.map((k) => MapEntry(k, _signedUrlCache[k]!)));
    }

    // Construir query string k=v1&k=v2...
    final query = keysToFetch.map((k) => 'keys=$k').join('&');
    try {
      final res =
          await ApiClient.getJson('/media/urls/batch?$query', withAuth: true);
      if (res['ok'] == true) {
        final items = res['items'] as List;
        for (var item in items) {
          _signedUrlCache[item['key']] = item['url'];
        }
      }
    } catch (e) {
      debugPrint('[UsersApi] Error batch fetching URLs: $e');
    }

    return Map.fromEntries(
        keys.map((k) => MapEntry(k, _signedUrlCache[k] ?? '')));
  }

  static String? getCachedUrl(String key) => _signedUrlCache[key];
}
