import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_preview_screen.dart'; // Import
import '../data/user_profile.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import 'compat_quiz_screen.dart';
import 'compat_summary_screen.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<bool> _checkQuizStatus() async {
    // Keep existing quiz check logic
    // This is a placeholder - actual quiz status check would go here
    return false;
  }

  Future<void> _openEditProfile(BuildContext context, WidgetRef ref, UserProfile? profile) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileEditScreen(profile: profile ?? UserProfile.empty()),
      ),
    );
    
    if (result == true) {
      // Profile was updated, reload
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
  }

  void _openSummary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CompatSummaryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_rounded), // Eye icon
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
            icon: const Icon(Icons.edit),
            onPressed: () {
              final profile = profileAsync.valueOrNull;
              _openEditProfile(context, ref, profile);
            },
            tooltip: 'Editar perfil',
          ),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          // Loading state
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          
          // Error state
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar perfil',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(profileProvider.notifier).loadProfile(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          
          // Data state
          data: (profile) {
            final hasProfile = profile.name != null && profile.name!.isNotEmpty;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header
                  _buildProfileHeader(context, profile, hasProfile),
                  
                  const SizedBox(height: 24),

                  // Photo Gallery Section
                  if (profile.photoUrls.isNotEmpty) ...[
                    _buildPhotoGallery(context, profile),
                    const SizedBox(height: 24),
                  ],

                  // Profile Completion Indicator
                  if (hasProfile) ...[
                    _buildCompletionIndicator(context, profile),
                    const SizedBox(height: 24),
                  ],

                  // LDS Information Card
                  if (hasProfile) ...[
                    _buildLDSInfoCard(context, profile),
                    const SizedBox(height: 24),
                  ],

                  // About Me Section
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    _buildAboutMeSection(context, profile),
                    const SizedBox(height: 24),
                  ],

                  // Details Section
                  if (hasProfile) ...[
                    _buildDetailsSection(context, profile),
                    const SizedBox(height: 24),
                  ],

                  // Interests Section
                  if (profile.interests.isNotEmpty) ...[
                    _buildInterestsSection(context, profile),
                    const SizedBox(height: 24),
                  ],

                  // Compatibility Quiz Section
                  _buildCompatibilitySection(context, ref),

                  const SizedBox(height: 24),

                  // Empty state message
                  if (!hasProfile) ...[
                    _buildEmptyState(context, ref),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserProfile profile, bool hasProfile) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        children: [
          // Profile Photo
          CircleAvatar(
            radius: 50,
            backgroundImage: profile.profilePhotoUrl != null
                ? FileImage(File(profile.profilePhotoUrl!))
                : null,
            child: profile.profilePhotoUrl == null
                ? Text(
                    profile.name?.substring(0, 1).toUpperCase() ?? 'C',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          
          // Name and Age
          Text(
            hasProfile
                ? '${profile.name}${profile.age != null ? ', ${profile.age}' : ''}'
                : 'Completa tu perfil',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Location
          if (profile.location != null && profile.location!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  profile.location!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionIndicator(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final percentage = profile.completionPercentage;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Completitud del perfil',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            if (percentage < 100) ...[
              const SizedBox(height: 8),
              Text(
                'Completa tu perfil para mejorar tus matches',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stake/Ward
            if (profile.stakeWard != null && profile.stakeWard!.isNotEmpty)
              _buildInfoRow(context, Icons.location_city, 'Estaca/Barrio', profile.stakeWard!),
            
            // Mission Served
            if (profile.missionServed != null && profile.missionServed!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.flight_takeoff,
                'Misión',
                profile.missionYears != null
                    ? '${profile.missionServed} (${profile.missionYears})'
                    : profile.missionServed!,
              ),
            ],
            
            // Temple Recommend
            if (profile.templeRecommend != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.account_balance,
                'Recomendación del templo',
                profile.templeRecommend!.displayName,
              ),
            ],
            
            // Activity Level
            if (profile.activityLevel != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.favorite,
                'Nivel de actividad',
                profile.activityLevel!.displayName,
              ),
            ],
            
            // Favorite Calling
            if (profile.favoriteCalling != null && profile.favoriteCalling!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.volunteer_activism,
                'Llamamiento favorito',
                profile.favoriteCalling!,
              ),
            ],
            
            // Favorite Scripture
            if (profile.favoriteScripture != null && profile.favoriteScripture!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.menu_book,
                'Escritura favorita',
                profile.favoriteScripture!,
              ),
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
            Text(
              'Sobre mí',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              profile.bio!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalles',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Height
            if (profile.heightCm != null)
              _buildInfoRow(context, Icons.height, 'Altura', profile.heightDisplay),
            
            // Education
            if (profile.education != null && profile.education!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(context, Icons.school, 'Educación', profile.education!),
            ],
            
            // Occupation
            if (profile.occupation != null && profile.occupation!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(context, Icons.work, 'Ocupación', profile.occupation!),
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
            Text(
              'Intereses',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests.map((interest) {
                return Chip(
                  label: Text(interest),
                  backgroundColor: theme.colorScheme.primaryContainer,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompatibilitySection(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final quizCompleted = false; // TODO: Implement quiz status check
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cuestionario de compatibilidad',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              quizCompleted
                  ? 'Ya completaste tu cuestionario de compatibilidad. Puedes actualizar tus respuestas cuando quieras.'
                  : 'Aún no has contestado tu cuestionario. Te haremos 12 preguntas para conocer mejor tus preferencias y ayudarte a encontrar personas afines.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _openQuiz(context, ref),
                    child: Text(
                      quizCompleted
                          ? 'Actualizar cuestionario'
                          : 'Responder cuestionario',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: quizCompleted ? () => _openSummary(context) : null,
                    child: const Text('Ver mis respuestas'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  quizCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: quizCompleted
                      ? Colors.green
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  quizCompleted
                      ? 'Cuestionario completado'
                      : 'Cuestionario pendiente',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: quizCompleted
                        ? Colors.green
                        : theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
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
              itemCount: profile.photoUrls.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(profile.photoUrls[index]),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
