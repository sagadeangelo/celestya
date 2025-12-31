// lib/data/user_profile.dart

/// Enum for temple recommend status
enum TempleRecommendStatus {
  tieneLa('Cuento con ella'),
  noPorElMomento('No por el momento'),
  trabajandoEnEllo('Trabajando en ello'),
  preferNotToSay('Prefiero no decir');

  final String displayName;
  const TempleRecommendStatus(this.displayName);

  static TempleRecommendStatus fromString(String value) {
    return TempleRecommendStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TempleRecommendStatus.preferNotToSay,
    );
  }
}

/// Enum for church activity level
enum ActivityLevel {
  veryActive('Muy activo'),
  active('Activo'),
  somewhatActive('Algo activo'),
  lessActive('Menos activo');

  final String displayName;
  const ActivityLevel(this.displayName);

  static ActivityLevel fromString(String value) {
    return ActivityLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActivityLevel.active,
    );
  }
}

/// Enum for gender
enum Gender {
  male('Hombre'),
  female('Mujer'),
  other('Otro');

  final String displayName;
  const Gender(this.displayName);

  static Gender fromString(String value) {
    return Gender.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Gender.male,
    );
  }
}

// Opciones de Complexión
const List<String> kBodyTypeOptions = [
  'Atlética / Tonificada 🏃',
  'Promedio ⚖️',
  'Con Curvas / Robusto 🍑',
  'Fuera de mi talla ✨',
];

const List<String> kInterestOptions = [
  'Templo 🏰', 'Misionero 👔', 'Genealogía 🌳', 'Noche de Hogar 🏠', 
  'Servicio 🤝', 'Escrituras 📖', 'Instituto 🎓', 'Coro 🎵', 
  'Himnos 🎶', 'Conferencia General 🎙️', 'Actividades de Barrio 🎉', 
  'Baile 💃', 'Cocina 🍳', 'Deporte ⚽', 'Naturaleza 🌲', 
  'Cine 🎬', 'Música 🎧', 'Lectura 📚', 'Tecnología 💻', 
  'Arte 🎨', 'Viajes ✈️', 'Fotografía 📷', 'Idiomas 🗣️', 
  'Juegos de Mesa 🎲', 'Camping ⛺', 'Senderismo 🥾', 
  'Ciclismo 🚴', 'Mascotas 🐾', 'Voluntariado ❤️', 'Teatro 🎭'
];

/// Comprehensive user profile model for LDS dating app
class UserProfile {
  // Basic Information
  final String? name;
  final int? age;
  final Gender? gender;
  final int? heightCm; // Height in centimeters
  final String? location; // City, State
  final String? bodyType; // Nueva: Complexión

  // LDS-Specific Information
  final String? stakeWard; // e.g., "Ciudad de México Stake, Polanco Ward"
  final String? missionServed; // e.g., "Mexico City South Mission"
  final String? missionYears; // e.g., "2018-2020"
  final TempleRecommendStatus? templeRecommend;
  final ActivityLevel? activityLevel;
  final String? favoriteCalling; // "Algún llamamiento que más hayas amado"
  final String? favoriteScripture; // Favorite verse from Bible or Book of Mormon

  // Personal Information
  final String? bio; // About me section
  final String? education;
  final String? occupation;
  final List<String> interests;

  // Photos
  final String? profilePhotoUrl;
  final List<String> photoUrls;

  const UserProfile({
    this.name,
    this.age,
    this.gender,
    this.heightCm,
    this.location,
    this.bodyType,
    this.stakeWard,
    this.missionServed,
    this.missionYears,
    this.templeRecommend,
    this.activityLevel,
    this.favoriteCalling,
    this.favoriteScripture,
    this.bio,
    this.education,
    this.occupation,
    this.interests = const [],
    this.profilePhotoUrl,
    this.photoUrls = const [],
  });

  /// Create an empty profile
  factory UserProfile.empty() {
    return const UserProfile();
  }

  /// Calculate profile completion percentage (0-100)
  int get completionPercentage {
    int totalFields = 16; // Total number of important fields
    int filledFields = 0;

    if (name != null && name!.isNotEmpty) filledFields++;
    if (age != null) filledFields++;
    if (gender != null) filledFields++;
    if (heightCm != null) filledFields++;
    if (location != null && location!.isNotEmpty) filledFields++;
    if (stakeWard != null && stakeWard!.isNotEmpty) filledFields++;
    if (templeRecommend != null) filledFields++;
    if (activityLevel != null) filledFields++;
    if (favoriteScripture != null && favoriteScripture!.isNotEmpty) filledFields++;
    if (bio != null && bio!.isNotEmpty) filledFields++;
    if (education != null && education!.isNotEmpty) filledFields++;
    if (occupation != null && occupation!.isNotEmpty) filledFields++;
    if (interests.isNotEmpty) filledFields++;
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty) filledFields++;
    if (photoUrls.length >= 3) filledFields++; // At least 3 photos
    // Mission and favorite calling are optional, so we count them as bonus
    if (missionServed != null && missionServed!.isNotEmpty) filledFields++;

    return ((filledFields / totalFields) * 100).round();
  }

  /// Check if profile has minimum required fields
  bool get isValid {
    return name != null &&
        name!.isNotEmpty &&
        age != null &&
        age! >= 18 &&
        gender != null &&
        profilePhotoUrl != null &&
        profilePhotoUrl!.isNotEmpty;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'gender': gender?.name,
      'heightCm': heightCm,
      'location': location,
      'stakeWard': stakeWard,
      'missionServed': missionServed,
      'missionYears': missionYears,
      'templeRecommend': templeRecommend?.name,
      'activityLevel': activityLevel?.name,
      'favoriteCalling': favoriteCalling,
      'favoriteScripture': favoriteScripture,
      'bio': bio,
      'education': education,
      'occupation': occupation,
      'bodyType': bodyType,
      'interests': interests,
      'profilePhotoUrl': profilePhotoUrl,
      'photoUrls': photoUrls,
    };
  }

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] != null
          ? Gender.fromString(json['gender'] as String)
          : null,
      heightCm: json['heightCm'] as int?,
      location: json['location'] as String?,
      stakeWard: json['stakeWard'] as String?,
      missionServed: json['missionServed'] as String?,
      missionYears: json['missionYears'] as String?,
      templeRecommend: json['templeRecommend'] != null
          ? TempleRecommendStatus.fromString(json['templeRecommend'] as String)
          : null,
      activityLevel: json['activityLevel'] != null
          ? ActivityLevel.fromString(json['activityLevel'] as String)
          : null,
      favoriteCalling: json['favoriteCalling'] as String?,
      favoriteScripture: json['favoriteScripture'] as String?,
      bio: json['bio'] as String?,
      education: json['education'] as String?,
      occupation: json['occupation'] as String?,
      bodyType: json['bodyType'] as String?,
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? name,
    int? age,
    Gender? gender,
    int? heightCm,
    String? location,
    String? stakeWard,
    String? missionServed,
    String? missionYears,
    TempleRecommendStatus? templeRecommend,
    ActivityLevel? activityLevel,
    String? favoriteCalling,
    String? favoriteScripture,
    String? bio,
    String? education,
    String? occupation,
    String? bodyType,
    List<String>? interests,
    String? profilePhotoUrl,
    List<String>? photoUrls,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      location: location ?? this.location,
      stakeWard: stakeWard ?? this.stakeWard,
      missionServed: missionServed ?? this.missionServed,
      missionYears: missionYears ?? this.missionYears,
      templeRecommend: templeRecommend ?? this.templeRecommend,
      activityLevel: activityLevel ?? this.activityLevel,
      favoriteCalling: favoriteCalling ?? this.favoriteCalling,
      favoriteScripture: favoriteScripture ?? this.favoriteScripture,
      bio: bio ?? this.bio,
      education: education ?? this.education,
      occupation: occupation ?? this.occupation,
      bodyType: bodyType ?? this.bodyType,
      interests: interests ?? this.interests,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  /// Convert height from cm to feet and inches
  String get heightInFeetInches {
    if (heightCm == null) return 'No especificado';
    final totalInches = (heightCm! / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\'$inches"';
  }

  /// Get height display string (both cm and feet/inches)
  String get heightDisplay {
    if (heightCm == null) return 'No especificado';
    return '$heightCm cm ($heightInFeetInches)';
  }
}
