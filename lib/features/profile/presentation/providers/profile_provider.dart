// lib/features/profile/presentation/providers/profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/user_profile.dart';
import '../../../../services/profile_service.dart';
import '../../../../services/quiz_api.dart';
import '../../../../services/users_api.dart'; // Added
import '../../../../providers/auth_provider.dart';

/// Provider para el servicio de perfil
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

/// Estado del perfil con AsyncValue para manejo de loading/error
final profileProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  // Watch auth changes to trigger profile reload on login
  ref.watch(authProvider);
  return ProfileNotifier(ref.read(profileServiceProvider));
});

// NUEVO: Provider para saber si el usuario ya completó el quiz
final quizStatusProvider = FutureProvider.autoDispose<bool>((ref) async {
  final answers = await QuizApi.getQuizAnswers();
  if (answers != null && answers.isNotEmpty) {
    return true;
  }
  return false;
});

/// Notifier para gestionar el estado del perfil
class ProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  final ProfileService _profileService;

  ProfileNotifier(this._profileService) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  /// Cargar perfil del usuario
  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      // 1. Cargar local primero para rapidez
      final localProfile = await _profileService.loadProfile();
      if (!localProfile.isEmpty) {
        state = AsyncValue.data(localProfile);
      }

      // 2. Intentar refrescar desde el backend para tener email_verified y datos reales
      final serverProfile = await UsersApi.getProfile();
      if (serverProfile != null) {
        // El backend y el modelo ya sanitizan el nombre.
        // Solo nos aseguramos de no tener un string "null" accidental.
        String? cleanedName = (serverProfile.name ?? localProfile.name);
        if (cleanedName != null) {
          cleanedName = cleanedName
              .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '')
              .trim();
          if (cleanedName.isEmpty) cleanedName = null;
        }

        final finalProfile = serverProfile.copyWith(
          name: cleanedName,
        );
        state = AsyncValue.data(finalProfile);
        await _profileService.saveProfile(finalProfile); // Cachear
      } else if (localProfile.isEmpty) {
        state = AsyncValue.data(UserProfile.empty());
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Actualizar perfil del usuario
  Future<void> updateProfile(UserProfile profile) async {
    // Optimistic update: actualizar UI inmediatamente
    state = AsyncValue.data(profile);

    try {
      await _profileService.saveProfile(profile);

      // Sync with backend !
      // We need to import UsersApi.
      // Assuming it's imported or available. If not, I'll add import in next step.
      await UsersApi.updateProfile(profile);

      // Recargar para asegurar consistencia
      await loadProfile();
    } catch (error, stackTrace) {
      // Si falla, revertir y mostrar error
      state = AsyncValue.error(error, stackTrace);
      // Recargar el perfil anterior
      await loadProfile();
    }
  }

  /// Limpiar perfil (logout)
  Future<void> clearProfile() async {
    state = const AsyncValue.loading();
    try {
      // Aquí podrías llamar a un método de logout en el servicio
      state = AsyncValue.data(UserProfile.empty());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
