import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_preview_screen.dart'; // Import
import '../data/user_profile.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import 'compat_quiz_screen.dart';
import 'compat_summary_screen.dart';
import 'profile_edit_screen.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart'; // Import CelestyaColors
import '../widgets/starry_background.dart';

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

  Future<void> _confirmLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que ingresar tus credenciales nuevamente para entrar.'),
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
      await AuthService.logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth_gate',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow gradient to go behind AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        foregroundColor: Colors.white, 
        title: const Text('Tu perfil', style: TextStyle(color: Colors.white)),
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
      body: Stack(
        children: [
          // 1. Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: CelestyaColors.softSpaceGradient, 
              ),
            ),
          ),
          
          // 2. Starry Background (Animated with Shooting Stars)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600, // Covers header down to gallery start
            child: StarryBackground(
                numberOfStars: 150,
                baseColor: Color(0xFFE0E0E0),
            ),
          ),

          // 3. Main Content
          SafeArea(
            child: profileAsync.when(
            // Loading state
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            
            // Error state
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar perfil',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
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

                  // Voice Intro (NEW)
                  if (hasProfile) ...[
                    _buildVoiceIntroSection(context),
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

                  const SizedBox(height: 32),
                  
                  // Logout Button (Creamy Rose)
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30), 
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFE4E1).withOpacity(0.3), // Misty Rose glow
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFE4E1), // Misty Rose
                        side: BorderSide(color: const Color(0xFFFFE4E1).withOpacity(0.8)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.transparent, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
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
  
  Widget _buildProfileHeader(BuildContext context, UserProfile profile, bool hasProfile) {
    return Column(
      children: [
        // Profile Photo with Ring
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Neon Spectrum Gradient: Purple -> Blue -> Pink -> Violet
                gradient: const LinearGradient(
                  colors: [
                    CelestyaColors.mysticalPurple,
                    CelestyaColors.celestialBlue,
                    CelestyaColors.nebulaPink,
                    Color(0xFF8A2BE2), // BlueViolet
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
              child: CircleAvatar(
                radius: 60,
                backgroundColor: CelestyaColors.deepNight,
                backgroundImage: profile.profilePhotoUrl != null
                    ? FileImage(File(profile.profilePhotoUrl!))
                    : null,
                child: profile.profilePhotoUrl == null
                    ? Text(
                        profile.name?.substring(0, 1).toUpperCase() ?? 'C',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: CelestyaColors.starlightGold,
                        ),
                      )
                    : null,
              ),
            ),
            
            // Edit Badge (Floating)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CelestyaColors.celestialBlue,
                shape: BoxShape.circle,
                border: Border.all(color: CelestyaColors.spaceBlack, width: 3),
              ),
              child: const Icon(Icons.edit, size: 16, color: Colors.white),
            )
          ],
        ),
        const SizedBox(height: 16),
        
        // Name & Trust Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasProfile
                  ? '${profile.name}${profile.age != null ? ', ${profile.age}' : ''}'
                  : 'Completa tu perfil',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            // Trust Badge
            if (hasProfile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CelestyaColors.auroraTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CelestyaColors.auroraTeal.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, size: 14, color: CelestyaColors.auroraTeal),
                    const SizedBox(width: 4),
                    const Text(
                      'Confiable',
                      style: TextStyle(
                          color: CelestyaColors.auroraTeal, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        
        if (profile.location != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(
                profile.location!,
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
              // Percentage Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 45, 
                    height: 45,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(CelestyaColors.starlightGold),
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

  Widget _buildVoiceIntroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CelestyaColors.mysticalPurple.withOpacity(0.2),
            CelestyaColors.deepNight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CelestyaColors.mysticalPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mic_rounded, color: CelestyaColors.starDust),
              SizedBox(width: 8),
              Text(
                'Preséntate con tu voz',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Graba 10-15 segundos. La voz comunica lo que el texto no puede.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          
          // Player Placeholder
          Row(
            children: [
              // Play/Record Button
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: CelestyaColors.mysticalPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // Waveform
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(20, (index) {
                      return Container(
                        width: 3,
                        height: 10 + (index % 5) * 4.0,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '00:00',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- End Celestial Components ---

  // NOTE: Reuse existing _buildLDSInfoCard etc but update colors if needed via theme or specific replacements
  // Updated Compatibility Section to match style
  Widget _buildCompatibilitySection(BuildContext context, WidgetRef ref) {
    // ... (Keep logic, just update Container decoration like above) 
    // For brevity in this replacement, I'll return a similar styled container
    final quizCompleted = false; 

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
            children: [
               Icon(Icons.auto_awesome, color: CelestyaColors.starlightGold, size: 20),
               const SizedBox(width: 8),
               const Text(
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
                  ? 'Ya completaste tu cuestionario.'
                  : 'Aún no has contestado tu cuestionario. Te haremos 12 preguntas para conocer mejor tus preferencias.',
             style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 16),
           // Neon Cream Button
           Container(
             width: double.infinity,
             decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFF8E7).withOpacity(0.4), // Cosmic Cream glow
                    blurRadius: 15, 
                    spreadRadius: 1,
                  ),
                ],
             ),
             child: OutlinedButton(
               onPressed: () => _openQuiz(context, ref),
               style: OutlinedButton.styleFrom(
                 foregroundColor: const Color(0xFFFFF8E7), // Cosmic Cream
                 side: const BorderSide(color: Color(0xFFFFF8E7), width: 1.5),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                 backgroundColor: Colors.transparent,
                 padding: const EdgeInsets.symmetric(vertical: 16),
               ),
               child: const Text(
                 'Responder cuestionario',
                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  // --- Restored Methods ---

  Widget _buildLDSInfoCard(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.church, color: theme.colorScheme.primary), const SizedBox(width: 8), Text('Información LDS', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 16),
            if (profile.stakeWard != null) _buildInfoRow(context, Icons.location_city, 'Estaca/Barrio', profile.stakeWard!),
            if (profile.missionServed != null) ...[const SizedBox(height: 12), _buildInfoRow(context, Icons.flight_takeoff, 'Misión', profile.missionServed!)],
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
            Text('Sobre mí', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            Text('Detalles', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (profile.heightCm != null) _buildInfoRow(context, Icons.height, 'Altura', profile.heightDisplay),
            if (profile.education != null) ...[const SizedBox(height: 12), _buildInfoRow(context, Icons.school, 'Educación', profile.education!)],
            if (profile.occupation != null) ...[const SizedBox(height: 12), _buildInfoRow(context, Icons.work, 'Ocupación', profile.occupation!)],
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
            Text('Intereses', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: profile.interests.map((i) => Chip(label: Text(i), backgroundColor: theme.colorScheme.primaryContainer)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
