// lib/features/profile/presentation/providers/profile_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/user_profile.dart';
import '../../../../services/profile_service.dart';

/// Provider para el servicio de perfil
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

/// Estado del perfil con AsyncValue para manejo de loading/error
final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return ProfileNotifier(ref.read(profileServiceProvider));
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
      final profile = await _profileService.loadProfile();
      state = AsyncValue.data(profile);
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
