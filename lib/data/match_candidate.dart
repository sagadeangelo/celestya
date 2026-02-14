// lib/data/match_candidate.dart

class MatchCandidate {
  final String id;
  final String name;
  final int? age;
  final String city;
  final String? photoUrl; // Foto principal (para compatibilidad)
  final List<String> photoUrls; // Lista de fotos para el carrusel
  final String? bio;

  // Atributos para filtros y detalles
  final double height; // cm
  final String exercise; // Ocasional, Regular, Diario
  final List<String> interests;
  final double compatibility; // 0.0 a 1.0 (100%)
  final String? bodyType; // Nuevo
  final String? voiceIntroPath;
  final String? maritalStatus; // Nuevo: 'Soltero(a)', etc.
  final bool? hasChildren; // Nuevo: true/false
  final String? photoKey;
  final double? latitude;
  final double? longitude;

  MatchCandidate({
    required this.id,
    required String name,
    this.age,
    required this.city,
    this.photoUrl,
    this.photoUrls = const [],
    this.bio,
    this.height = 0,
    this.exercise = '',
    this.interests = const [],
    this.compatibility = 0.5,
    this.bodyType,
    this.voiceIntroPath,
    this.maritalStatus,
    this.hasChildren,
    this.photoKey,
    this.latitude,
    this.longitude,
  }) : name = _cleanName(name);

  static String _cleanName(String rawName) {
    String cleanedName = rawName
        .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[,\\.\\s]+$'), '')
        .replaceAll(RegExp(r'^[,\\.\\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // If after cleaning, the name is empty or effectively "null",
    // we might want to handle it, but since 'name' is non-nullable,
    // we'll default to an empty string or throw an error if it's critical.
    // For now, an empty string is the most graceful non-null fallback.
    if (cleanedName.isEmpty || cleanedName.toLowerCase() == "null") {
      return ''; // Return an empty string for non-nullable 'name'
    }
    return cleanedName;
  }
}
