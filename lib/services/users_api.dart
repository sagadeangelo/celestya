import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Me {
  final int id;
  final String email;
  final String? photoUrl;
  Me({required this.id, required this.email, this.photoUrl});

  factory Me.fromJson(Map<String, dynamic> j) =>
      Me(id: j['id'] as int, email: j['email'] as String, photoUrl: j['photo_url'] as String?);
}

class UsersApi {
  static Future<Me> me() async {
    final json = await ApiClient.getJson('/users/me', withAuth: true);
    return Me.fromJson(json);
  }

  static Future<String> uploadPhoto(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final req = http.MultipartRequest('POST', Uri.parse('${ApiClient.API_BASE}/users/me/photo'));
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: file.uri.pathSegments.last,
      contentType: MediaType('image', _extToSubtype(file.path)),
    ));
    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final url = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1);
      if (url == null) throw Exception('Respuesta sin url: $body');
      return url;
    }
    throw Exception('HTTP ${res.statusCode}: $body');
  }

  static String _extToSubtype(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'png';
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'jpeg';
    if (p.endsWith('.webp')) return 'webp';
    return 'jpeg';
    }
}
