import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_preview_screen.dart';
import '../data/user_profile.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import 'compat_quiz_screen.dart';
import 'compat_summary_screen.dart';
import 'profile_edit_screen.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';
import '../widgets/voice_intro_widget.dart';
import 'package:celestya/screens/image_viewer_screen.dart';
import '../widgets/profile_image.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Normaliza strings para evitar mostrar "null", "undefined", espacios, etc.
  String? _cleanString(String? v) {
    if (v == null) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    final low = s.toLowerCase();
    if (low == 'null' || low == 'undefined' || low == 'none') return null;
    return s;
  }

  Future<bool> _checkQuizStatus() async {
    return false;
  }

  Future<void> _openEditProfile(
      BuildContext context, WidgetRef ref, UserProfile? profile) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProfileEditScreen(profile: profile ?? UserProfile.empty()),
      ),
    );

    if (result == true) {
      ref.read(profileProvider.notifier).loadProfile();
    }
  }

  Future<void> _openQuiz(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CompatQuizScreen(),
      ),
    );
    ref.read(profileProvider.notifier).loadProfile();
    ref.refresh(quizStatusProvider);
  }

  void _openSummary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CompatSummaryScreen(),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
            'Tendrás que ingresar tus credenciales nuevamente para entrar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth_gate',
          (route) => false,
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar cuenta?'),
        content: const Text(
          'Esta acción es irreversible. Se eliminarán todos tus datos, matches y fotos de nuestros servidores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('ELIMINAR MI CUENTA'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient.deleteMyAccount();
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta eliminada correctamente')),
          );
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/auth_gate',
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar cuenta: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_rounded, size: 20),
            tooltip: 'Vista Previa como Match',
            onPressed: () {
              final profile = profileAsync.valueOrNull;
              if (profile != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ProfilePreviewScreen(profile: profile),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              final profile = profileAsync.valueOrNull;
              _openEditProfile(context, ref, profile);
            },
            tooltip: 'Editar perfil',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: CelestyaColors.vibrantCelestialGradient,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600,
            child: StarryBackground(
              numberOfStars: 150,
              baseColor: const Color(0xFFE0E0E0),
            ),
          ),
          SafeArea(
            child: profileAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar perfil',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.read(profileProvider.notifier).loadProfile(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (profile) {
                final cleanedName = _cleanString(profile.name);
                final hasProfile = cleanedName != null;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(context, profile, hasProfile),
                      const SizedBox(height: 24),
                      if (profile.photoUrls.isNotEmpty) ...[
                        _buildPhotoGallery(context, profile),
                        const SizedBox(height: 24),
                      ],
                      if (hasProfile) ...[
                        _buildCompletionIndicator(context, profile),
                        const SizedBox(height: 24),
                      ],
                      if (hasProfile) ...[
                        VoiceIntroWidget(profile: profile, ref: ref),
                        const SizedBox(height: 24),
                      ],
                      if (hasProfile) ...[
                        _buildLDSInfoCard(context, profile),
                        const SizedBox(height: 24),
                      ],
                      if (_cleanString(profile.bio) != null) ...[
                        _buildAboutMeSection(context, profile),
                        const SizedBox(height: 24),
                      ],
                      if (hasProfile) ...[
                        _buildDetailsSection(context, profile),
                        const SizedBox(height: 24),
                      ],
                      if (profile.interests.isNotEmpty) ...[
                        _buildInterestsSection(context, profile),
                        const SizedBox(height: 24),
                      ],
                      _buildCompatibilitySection(context, ref),
                      const SizedBox(height: 24),
                      if (!hasProfile) ...[
                        _buildEmptyState(context, ref),
                      ],
                      const SizedBox(height: 32),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFE4E1).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmLogout(context, ref),
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar sesión'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFE4E1),
                            side: BorderSide(
                                color:
                                    const Color(0xFFFFE4E1).withOpacity(0.8)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _confirmDeleteAccount(context, ref),
                        icon: const Icon(Icons.delete_forever, size: 20),
                        label: const Text('Eliminar mi cuenta'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Celestial Profile Components ---

  Widget _buildProfileHeader(
      BuildContext context, UserProfile profile, bool hasProfile) {
    final displayName =
        hasProfile ? formatDisplayName(profile) : 'Completa tu perfil';

    final initials = (hasProfile && displayName.isNotEmpty)
        ? displayName.substring(0, 1).toUpperCase()
        : 'C';

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            final mainUrl =
                profile.photoUrls.isNotEmpty ? profile.photoUrls.first : null;
            if (mainUrl != null) {
              ImageViewerScreen.open(context, [mainUrl], 0);
            }
          },
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      CelestyaColors.mysticalPurple,
                      CelestyaColors.celestialBlue,
                      CelestyaColors.nebulaPink,
                      Color(0xFF8A2BE2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CelestyaColors.mysticalPurple.withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: CelestyaColors.celestialBlue.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                      offset: const Offset(-2, -2),
                    ),
                  ],
                ),
                child: ProfileImage(
                  photoKey: profile.profilePhotoKey,
                  photoPath: profile.profilePhotoUrl,
                  radius: 60,
                  placeholder: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: CelestyaColors.starlightGold,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CelestyaColors.celestialBlue,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: CelestyaColors.spaceBlack, width: 3),
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (hasProfile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CelestyaColors.auroraTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: CelestyaColors.auroraTeal.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 14, color: CelestyaColors.auroraTeal),
                    SizedBox(width: 4),
                    Text(
                      'Confiable',
                      style: TextStyle(
                        color: CelestyaColors.auroraTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (profile.location != null && profile.location!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(
                '${profile.location}${profile.age != null ? ', ${profile.age} años' : ''}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompletionIndicator(BuildContext context, UserProfile profile) {
    final percentage = profile.completionPercentage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CelestyaColors.deepNight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu progreso',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Un perfil completo atrae conexiones más profundas',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 45,
                    height: 45,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(
                          CelestyaColors.starlightGold),
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: CelestyaColors.starlightGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection(BuildContext context, WidgetRef ref) {
    final quizStatusAsync = ref.watch(quizStatusProvider);
    final quizCompleted = quizStatusAsync.value ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CelestyaColors.deepNight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome,
                  color: CelestyaColors.starlightGold, size: 20),
              SizedBox(width: 8),
              Text(
                'Cuestionario de compatibilidad',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quizCompleted
                ? '¡Ya completaste tu cuestionario! Tus respuestas nos ayudan a encontrar mejores conexiones.'
                : 'Aún no has contestado tu cuestionario. Te haremos 12 preguntas para conocer mejor tus preferencias.',
            style:
                TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: quizCompleted
                  ? []
                  : [
                      BoxShadow(
                        color: CelestyaColors.mysticalPurple.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: OutlinedButton(
              onPressed: quizCompleted ? null : () => _openQuiz(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    quizCompleted ? Colors.white38 : const Color(0xFFFFF8E7),
                side: BorderSide(
                    color: quizCompleted
                        ? Colors.white12
                        : const Color(0xFFFFF8E7),
                    width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                quizCompleted
                    ? 'Cuestionario completado'
                    : 'Responder cuestionario',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.person_add,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Completa tu perfil',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu información personal, detalles LDS, y fotos para comenzar a conectar con personas afines.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final profile = ref.read(profileProvider).valueOrNull;
                _openEditProfile(context, ref, profile);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Editar perfil'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGallery(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final photoKeys = profile.galleryPhotoKeys;
    final photoUrls = profile.photoUrls;

    if (photoKeys.isEmpty && photoUrls.isEmpty) return const SizedBox.shrink();

    final displayPhotos = photoUrls.isNotEmpty ? photoUrls : photoKeys;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Mis fotos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: displayPhotos.length,
              itemBuilder: (context, index) {
                final photo = displayPhotos[index];
                final bool isDirectUrl = photo.startsWith('http');

                return GestureDetector(
                  onTap: () =>
                      ImageViewerScreen.open(context, displayPhotos, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isDirectUrl
                        ? Image.network(
                            photo,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 20),
                            ),
                          )
                        : ProfileImage(
                            photoKey: photo,
                            radius: 50,
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLDSInfoCard(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.church, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Información LDS',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profile.stakeWard != null)
              _buildInfoRow(context, Icons.location_city, 'Estaca/Barrio',
                  profile.stakeWard!),
            if (profile.missionServed != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(context, Icons.flight_takeoff, 'Misión',
                  profile.missionServed!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAboutMeSection(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sobre mí',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(profile.bio ?? '', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, UserProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detalles',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (profile.heightCm != null)
              _buildInfoRow(
                  context, Icons.height, 'Altura', profile.heightDisplay),
            if (profile.maritalStatus != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(context, Icons.favorite, 'Estado Civil',
                  profile.maritalStatus!.displayName),
            ],
            if (profile.education != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                  context, Icons.school, 'Educación', profile.education!),
            ],
            if (profile.occupation != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                  context, Icons.work, 'Ocupación', profile.occupation!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsSection(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Intereses',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests
                  .map((i) => Chip(
                      label: Text(i),
                      backgroundColor: theme.colorScheme.primaryContainer))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
