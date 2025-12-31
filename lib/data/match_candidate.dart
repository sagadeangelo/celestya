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

  const MatchCandidate({
    required this.id,
    required this.name,
    this.age,
    required this.city,
    this.photoUrl,
    this.photoUrls = const [],
    this.bio,
    this.height = 0,
    this.exercise = '',
    this.interests = const [],
    this.compatibility = 0.5, // Default 50%
    this.bodyType,
  });
}
