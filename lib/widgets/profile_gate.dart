import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_profile.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';

class ProfileGate extends ConsumerWidget {
  final Widget child;

  const ProfileGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        if (profile.isReadyForMatching) {
          return child;
        } else {
          return _IncompleteProfileView(profile: profile);
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _IncompleteProfileView extends ConsumerWidget {
  final UserProfile profile;

  const _IncompleteProfileView({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> missing = [];
    if (!profile.emailVerified) missing.add('Verificar correo electrónico');
    if (profile.location == null || profile.location!.isEmpty) {
      missing.add('Ciudad de residencia');
    }
    if (profile.profilePhotoUrl == null || profile.profilePhotoUrl!.isEmpty) {
      missing.add('Foto de perfil');
    }
    if (profile.name == null || profile.name!.isEmpty) missing.add('Tu nombre');
    if (profile.gender == null) missing.add('Género');
    if (profile.birthdate == null) missing.add('Fecha de nacimiento');

    // Opcional: Podríamos pedir verificación aquí si el usuario lo desea
    if (profile.verificationStatus == 'none' ||
        profile.verificationStatus == null) {
      missing.add('Verificación de Identidad (Sel selfie)');
    }

    return Scaffold(
      backgroundColor: CelestyaColors.deepNight,
      appBar: AppBar(
        title: const Text('Completa tu perfil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person_outlined,
                size: 80, color: CelestyaColors.mysticalPurple),
            const SizedBox(height: 24),
            const Text(
              '¡Casi listo para conectar!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Para acceder a Descubrir y Matches, necesitamos que completes los siguientes pasos:',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...missing.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.amber, size: 20),
                      const SizedBox(width: 12),
                      Text(item,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                    ],
                  ),
                )),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                // Switch to Profile Tab (Index 3 in AppShell)
                ref.read(navIndexProvider.notifier).state = 3;
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CelestyaColors.mysticalPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Crear Perfil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
