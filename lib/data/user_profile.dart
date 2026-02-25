// lib/data/user_profile.dart
import 'dart:io';

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

/// Enum for marital status
enum MaritalStatus {
  single('Soltero(a)'),
  divorced('Divorciado(a)'),
  widowed('Viudo(a)'),
  separated('Separado(a)');

  final String displayName;
  const MaritalStatus(this.displayName);

  static MaritalStatus fromString(String value) {
    return MaritalStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MaritalStatus.single,
    );
  }
}

/// Enum for gender
enum Gender {
  male('Hombre'),
  female('Mujer');

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
  'Delgado (Ectomorfo) 📏',
  'Atlético (Mesomorfo) 🏋️',
  'Promedio 🧍',
  'Robusto (Endomorfo) 🧸',
];

const List<String> kInterestOptions = [
  'Templo 🏰',
  'Misionero 👔',
  'Genealogía 🌳',
  'Noche de Hogar 🏠',
  'Servicio 🤝',
  'Escrituras 📖',
  'Instituto 🎓',
  'Coro 🎵',
  'Himnos 🎶',
  'Conferencia General 🎙️',
  'Actividades de Barrio 🎉',
  'Baile 💃',
  'Cocina 🍳',
  'Deporte ⚽',
  'Naturaleza 🌲',
  'Cine 🎬',
  'Música 🎧',
  'Lectura 📚',
  'Tecnología 💻',
  'Arte 🎨',
  'Viajes ✈️',
  'Fotografía 📷',
  'Idiomas 🗣️',
  'Juegos de Mesa 🎲',
  'Camping ⛺',
  'Senderismo 🥾',
  'Ciclismo 🚴',
  'Mascotas 🐾',
  'Voluntariado ❤️',
  'Teatro 🎭'
];

/// Unified model for gallery photos (local or remote)
class GalleryItem {
  final String? key;
  final File? file;
  final String? url;

  GalleryItem({this.key, this.file, this.url});

  bool get isLocal => file != null;
  bool get isRemote => key != null;

  GalleryItem copyWith({String? key, File? file, String? url}) {
    return GalleryItem(
      key: key ?? this.key,
      file: file ?? this.file,
      url: url ?? this.url,
    );
  }
}

/// --- Helpers (muy importantes para matar el "null") ---
String? _cleanString(dynamic v) {
  if (v == null) return null;
  final s = v.toString();

  // Quita "null" en cualquier forma, y arregla comas/espacios raros
  var out = s
      .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '')
      .replaceAll(RegExp(r',\s*,+'), ', ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s*,\s*$'), '') // coma al final
      .trim();

  if (out.isEmpty) return null;
  if (out.toLowerCase() == 'null') return null;
  return out;
}

/// Helper to format name for display, guaranteeing no "null"
String formatDisplayName(UserProfile p) {
  final cleanName = _cleanString(p.name);
  if (cleanName == null || cleanName.isEmpty) {
    return 'Tu nombre';
  }
  return cleanName;
}

bool _hasValue(String? s) => (s != null && s.trim().isNotEmpty);

/// Comprehensive user profile model for LDS dating app
class UserProfile {
  // Basic Information
  final String? name;
  final DateTime? birthdate;
  final int? age;
  final Gender? gender;
  final int? heightCm; // Height in centimeters
  final String? location; // City, State
  final double? latitude;
  final double? longitude;
  final String? bodyType; // Complexión
  final MaritalStatus? maritalStatus; // Estado civil
  final bool? hasChildren;
  final bool emailVerified; // gate

  // LDS-Specific Information
  final String? stakeWard;
  final String? missionServed;
  final String? missionYears;
  final TempleRecommendStatus? templeRecommend;
  final ActivityLevel? activityLevel;
  final String? favoriteCalling;
  final String? favoriteScripture;

  // Personal Information
  final String? bio;
  final String? education;
  final String? occupation;
  final List<String> interests;

  // Foto principal (Legacy / Cache)
  final String? profilePhotoUrl;
  final List<String> photoUrls;

  // Foto R2
  final String? profilePhotoKey;
  final List<String> galleryPhotoKeys;

  final String? voiceIntroPath;

  // Verification
  final String? verificationStatus;
  final String? rejectionReason;
  final String? activeInstruction;
  final int? verificationAttempt;

  const UserProfile({
    this.name,
    this.age,
    this.gender,
    this.heightCm,
    this.location,
    this.latitude,
    this.longitude,
    this.bodyType,
    this.maritalStatus,
    this.hasChildren,
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
    this.voiceIntroPath,
    this.emailVerified = false,
    this.birthdate,
    this.profilePhotoKey,
    this.galleryPhotoKeys = const [],
    this.verificationStatus,
    this.rejectionReason,
    this.activeInstruction,
    this.verificationAttempt,
  });

  factory UserProfile.empty() => const UserProfile();

  bool get isEmpty =>
      (_cleanString(name) == null) &&
      !_hasValue(profilePhotoKey) &&
      !_hasValue(location);

  bool get isProfileComplete {
    final cleanName = _cleanString(name) ?? "";
    final hasName = cleanName.isNotEmpty;
    final hasPhoto = (_hasValue(profilePhotoKey) || _hasValue(profilePhotoUrl));
    final hasCity = _hasValue(location);
    return hasName && hasPhoto && hasCity;
  }

  int get completionPercentage {
    int totalFields = 5; // Nombre, Foto, Edad, Género, Ubicación
    int filledFields = 0;

    if (_hasValue(_cleanString(name))) filledFields++;
    if (gender != null) filledFields++;
    if ((age ?? ageFromBirthdate) != null) filledFields++;
    if (_hasValue(location)) filledFields++;
    final hasPhoto = (_hasValue(profilePhotoKey) || _hasValue(profilePhotoUrl));
    if (hasPhoto) filledFields++;

    return ((filledFields / totalFields) * 100).round();
  }

  bool get isValid {
    final hasPhoto = (_hasValue(profilePhotoKey) || _hasValue(profilePhotoUrl));
    final hasName = _hasValue(_cleanString(name));
    final hasAge = (age ?? ageFromBirthdate) != null;
    final hasGender = gender != null;
    return hasName && hasAge && hasGender && hasPhoto;
  }

  bool get isReadyForMatching {
    if (!_hasValue(location)) return false;
    // Si quieres que la verificación sea obligatoria para matches, descomenta la siguiente línea:
    // if (verificationStatus == 'none' || verificationStatus == 'rejected') return false;
    return isValid;
  }

  /// Convert to JSON (SOLO campos que se deben actualizar).
  /// Clave: NO mandar 'photo_urls', 'email_verified', etc. para no pisar datos.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};

    void put(String k, dynamic v) {
      if (v == null) return;
      if (v is String && v.trim().isEmpty) return;
      data[k] = v;
    }

    // Limpieza fuerte del nombre antes de enviar
    final cleanName = _cleanString(name);
    put('name', cleanName);

    // birthdate en YYYY-MM-DD
    if (birthdate != null) {
      put('birthdate', birthdate!.toIso8601String().split('T')[0]);
    }

    // Básicos
    put('gender', gender?.name);

    // Compat: manda snake_case y camelCase (por si el backend usa alias)
    if (heightCm != null) {
      put('height_cm', heightCm);
      put('heightCm', heightCm);
    }

    put('city', _cleanString(location));
    put('lat', latitude);
    put('lon', longitude);

    put('stake', _cleanString(stakeWard));

    // LDS compat (snake + camel)
    final ms = _cleanString(missionServed);
    if (ms != null) {
      put('mission_served', ms);
      put('missionServed', ms);
    }

    final my = _cleanString(missionYears);
    if (my != null) {
      put('mission_years', my);
      put('missionYears', my);
    }

    put('temple_recommend', templeRecommend?.name);
    put('activity_level', activityLevel?.name);

    final fc = _cleanString(favoriteCalling);
    if (fc != null) {
      put('favorite_calling', fc);
      put('favoriteCalling', fc);
    }

    final fs = _cleanString(favoriteScripture);
    if (fs != null) {
      put('favorite_scripture', fs);
      put('favoriteScripture', fs);
    }

    // Personal
    put('bio', _cleanString(bio));
    put('education', _cleanString(education));
    put('occupation', _cleanString(occupation));

    // Complexión / estado civil / hijos
    put('body_type', _cleanString(bodyType));

    if (maritalStatus != null) {
      put('marital_status', maritalStatus!.name);
      put('maritalStatus', maritalStatus!.name);
    }

    if (hasChildren != null) {
      put('has_children', hasChildren);
      put('hasChildren', hasChildren);
    }

    // Intereses
    if (interests.isNotEmpty) {
      put('interests', interests);
    }

    // Fotos: SOLO keys que el backend guarda
    if (_hasValue(profilePhotoKey)) {
      put('profile_photo_key', profilePhotoKey);
    }

    if (galleryPhotoKeys.isNotEmpty) {
      put('gallery_photo_keys', galleryPhotoKeys);
    }

    // NO enviar: photo_urls (son de lectura), email_verified (server), profile_photo_url (legacy)
    // NO enviar: age (se calcula), location duplicada, etc.

    // Debug
    // ignore: avoid_print
    print('[UserProfile] toJson (clean): $data');

    return data;
  }

  /// Create from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Debug log to catch "null" origin
    print(
        '[UserProfile] Raw JSON name: "${json['name']}", display_name: "${json['display_name']}"');

    // Limpieza agresiva del nombre (mata "Miguel ..., null")
    final rawName = _cleanString(json['name'] ?? json['display_name']);

    return UserProfile(
      name: rawName,
      birthdate: json['birthdate'] != null
          ? DateTime.tryParse(json['birthdate'] as String)
          : null,
      age: json['age'] as int?,
      gender: json['gender'] != null
          ? Gender.fromString(json['gender'] as String)
          : (json['show_me'] != null
              ? Gender.fromString(json['show_me'] as String)
              : null),

      // Compat: acepta snake o camel
      heightCm: (json['height_cm'] as int?) ?? (json['heightCm'] as int?),

      location: _cleanString(json['city']),
      latitude: (json['lat'] as num?)?.toDouble(),
      longitude: (json['lon'] as num?)?.toDouble(),
      stakeWard: _cleanString(json['stake']),

      missionServed:
          _cleanString(json['mission_served'] ?? json['missionServed']),
      missionYears: _cleanString(json['mission_years'] ?? json['missionYears']),

      templeRecommend: (json['temple_recommend'] ?? json['templeRecommend']) !=
              null
          ? TempleRecommendStatus.fromString(
              (json['temple_recommend'] ?? json['templeRecommend']) as String)
          : null,

      activityLevel: (json['activity_level'] ?? json['activityLevel']) != null
          ? ActivityLevel.fromString(
              (json['activity_level'] ?? json['activityLevel']) as String)
          : null,

      favoriteCalling:
          _cleanString(json['favorite_calling'] ?? json['favoriteCalling']),
      favoriteScripture:
          _cleanString(json['favorite_scripture'] ?? json['favoriteScripture']),

      bio: _cleanString(json['bio']),
      education: _cleanString(json['education']),
      occupation: _cleanString(json['occupation']),

      bodyType: _cleanString(json['body_type']),
      maritalStatus: (json['marital_status'] ?? json['maritalStatus']) != null
          ? MaritalStatus.fromString(
              (json['marital_status'] ?? json['maritalStatus']) as String)
          : null,
      hasChildren:
          (json['has_children'] as bool?) ?? (json['hasChildren'] as bool?),

      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],

      // Foto principal (R2)
      profilePhotoKey: _cleanString(json['profile_photo_key']),

      // Legacy local (si el backend aún lo manda)
      profilePhotoUrl: _cleanString(json['photo_url']),

      // Signed URLs (read only)
      photoUrls: (json['photo_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],

      voiceIntroPath:
          _cleanString(json['voice_intro_path'] ?? json['voiceIntroPath']),
      emailVerified: json['email_verified'] as bool? ?? false,

      galleryPhotoKeys: (json['gallery_photo_keys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      verificationStatus:
          json['verification_status'] ?? json['verificationStatus'],
      rejectionReason: json['rejection_reason'] ?? json['rejectionReason'],
      activeInstruction:
          json['active_instruction'] ?? json['activeInstruction'],
      verificationAttempt:
          json['verification_attempt'] ?? json['verificationAttempt'],
    );
  }

  UserProfile copyWith({
    String? name,
    DateTime? birthdate,
    int? age,
    Gender? gender,
    int? heightCm,
    String? location,
    double? latitude,
    double? longitude,
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
    MaritalStatus? maritalStatus,
    bool? hasChildren,
    List<String>? interests,
    String? profilePhotoUrl,
    String? profilePhotoKey,
    List<String>? galleryPhotoKeys,
    List<String>? photoUrls,
    String? voiceIntroPath,
    bool? emailVerified,
    String? verificationStatus,
    String? rejectionReason,
    String? activeInstruction,
    int? verificationAttempt,
  }) {
    return UserProfile(
      name: name ?? this.name,
      birthdate: birthdate ?? this.birthdate,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
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
      maritalStatus: maritalStatus ?? this.maritalStatus,
      hasChildren: hasChildren ?? this.hasChildren,
      interests: interests ?? this.interests,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      profilePhotoKey: profilePhotoKey ?? this.profilePhotoKey,
      galleryPhotoKeys: galleryPhotoKeys ?? this.galleryPhotoKeys,
      photoUrls: photoUrls ?? this.photoUrls,
      voiceIntroPath: voiceIntroPath ?? this.voiceIntroPath,
      emailVerified: emailVerified ?? this.emailVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      activeInstruction: activeInstruction ?? this.activeInstruction,
      verificationAttempt: verificationAttempt ?? this.verificationAttempt,
    );
  }

  String get heightInFeetInches {
    if (heightCm == null) return 'No especificado';
    final totalInches = (heightCm! / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$feet\'$inches"';
  }

  String get heightDisplay {
    if (heightCm == null) return 'No especificado';
    return '$heightCm cm ($heightInFeetInches)';
  }

  int? get ageFromBirthdate {
    if (birthdate == null) return null;

    final today = DateTime.now();
    int a = today.year - birthdate!.year;

    if (today.month < birthdate!.month ||
        (today.month == birthdate!.month && today.day < birthdate!.day)) {
      a--;
    }
    return a;
  }
}
