// lib/screens/profile_preview_screen.dart
import 'package:flutter/material.dart';
import '../data/match_candidate.dart';
import '../data/user_profile.dart';
import '../widgets/premium_match_card.dart';
import '../theme/app_theme.dart';

class ProfilePreviewScreen extends StatelessWidget {
  final UserProfile profile;

  const ProfilePreviewScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    // Map UserProfile to MatchCandidate for the card
    final candidate = MatchCandidate(
      id: 'preview',
      name: formatDisplayName(profile),
      age: profile.age,
      city: profile.location ?? 'Ubicación no definida',
      photoUrl: profile.profilePhotoUrl,
      photoKey: profile.profilePhotoKey,
      photoUrls: profile.photoUrls, // Ahora contiene URLs firmadas del backend
      bio: profile.bio,
      height: profile.heightCm?.toDouble() ?? 0,
      exercise: '', // No mapped in UserProfile properly yet, defaulting
      interests: profile.interests,
      compatibility: 0.0, // Hidden for own profile preview
      voiceIntroPath: profile.voiceIntroPath,
      voiceIntroUrl: profile.voiceIntroUrl,
      bodyType: profile.bodyType,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: CelestyaColors.vibrantCelestialGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: PremiumMatchCard(
                      candidate: candidate,
                      isPreview: true, // Enable photo navigation
                    ),
                  ),
                ),
              ),

              // Botón Cerrar
              Positioned(
                top: 30,
                right: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),

              // Etiqueta "Vista Previa"
              Positioned(
                top: 30,
                left: 30,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Vista Previa',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
