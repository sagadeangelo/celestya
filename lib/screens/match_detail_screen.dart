import 'package:flutter/material.dart';
import '../data/match_candidate.dart';
import '../theme/app_theme.dart';

class MatchDetailScreen extends StatelessWidget {
  final MatchCandidate candidate;

  const MatchDetailScreen({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CelestyaColors.deepNight,
      body: CustomScrollView(
        slivers: [
          // 1. Expanded Photo AppBar
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.6,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'match_photo_${candidate.id}',
                child: Image.network(
                  candidate.photoUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
                ),
              ),
            ),
          ),

          // 2. Profile Details
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: CelestyaColors.deepNight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                gradient: CelestyaColors.softSpaceGradient, 
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Header Name & Age
                   Row(
                     children: [
                       Expanded(
                         child: Text(
                           '${candidate.name}, ${candidate.age}',
                           style: Theme.of(context).textTheme.displaySmall?.copyWith(
                             color: Colors.white,
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                       ),
                       // Compatibility Badge
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                         decoration: BoxDecoration(
                           color: CelestyaColors.celestialBlue.withOpacity(0.2),
                           borderRadius: BorderRadius.circular(20),
                           border: Border.all(color: CelestyaColors.celestialBlue),
                         ),
                         child: Row(
                           children: [
                             Icon(
                               candidate.compatibility > 0.8 ? Icons.favorite : Icons.bolt,
                               color: CelestyaColors.celestialBlue,
                               size: 16,
                             ),
                             const SizedBox(width: 4),
                             Text(
                               '${(candidate.compatibility * 100).toInt()}%',
                               style: const TextStyle(
                                 color: Colors.white, 
                                 fontWeight: FontWeight.bold
                               ),
                             ),
                           ],
                         ),
                       )
                     ],
                   ),
                   const SizedBox(height: 8),
                   
                   // Location
                   Row(
                     children: [
                       const Icon(Icons.location_on_outlined, color: Colors.white70, size: 18),
                       const SizedBox(width: 8),
                       Text(
                         candidate.city,
                         style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                           color: Colors.white70,
                         ),
                       ),
                     ],
                   ),
                   
                   const SizedBox(height: 24),
                   const Divider(color: Colors.white10),
                   const SizedBox(height: 24),

                   // Bio
                   Text(
                     'Sobre mí',
                     style: Theme.of(context).textTheme.titleLarge?.copyWith(
                       color: CelestyaColors.starlightGold,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     candidate.bio ?? 'Sin descripción.',
                     style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                       color: Colors.white.withOpacity(0.9),
                       height: 1.5,
                     ),
                   ),

                   const SizedBox(height: 30),

                   // Interests
                   if (candidate.interests.isNotEmpty) ...[
                      Text(
                       'Intereses',
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         color: CelestyaColors.starlightGold,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     const SizedBox(height: 16),
                     Wrap(
                       spacing: 10,
                       runSpacing: 10,
                       children: candidate.interests.map((interest) => 
                         Chip(
                           label: Text(interest),
                           backgroundColor: CelestyaColors.mysticalPurple.withOpacity(0.3),
                           labelStyle: const TextStyle(color: Colors.white),
                           side: BorderSide.none,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                         )
                       ).toList(),
                     ),
                     const SizedBox(height: 30),
                   ],
                   
                   // Lifestyle / Basics
                   _buildInfoRow(Icons.height, 'Altura', '${candidate.height.round()} cm'),
                   _buildInfoRow(Icons.fitness_center, 'Ejercicio', candidate.exercise),
                   _buildInfoRow(Icons.person, 'Complexión', candidate.bodyType ?? 'No especificado'),

                   const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
      // Floating Action Buttons (Dislike / Like) could go here too if desired
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
