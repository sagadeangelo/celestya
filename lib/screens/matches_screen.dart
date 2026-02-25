// lib/screens/matches_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/discover_provider.dart';

import '../data/match_candidate.dart';
import '../widgets/empty_state.dart';
import '../widgets/starry_background.dart';
import '../theme/app_theme.dart';
import '../services/matches_api.dart';
import '../features/chats/chats_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import 'match_detail_screen.dart';

/// Provider: carga MATCHES CONFIRMADOS desde backend
final confirmedMatchesProvider =
    FutureProvider.autoDispose<List<MatchCandidate>>((ref) async {
  return MatchesApi.getConfirmed();
});

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmedAsync = ref.watch(confirmedMatchesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Matches',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.refresh(confirmedMatchesProvider),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration:
                const BoxDecoration(gradient: CelestyaColors.softSpaceGradient),
          ),
          const Positioned.fill(
            child: StarryBackground(
                numberOfStars: 80, baseColor: Color(0xFFE0E0E0)),
          ),
          SafeArea(
            child: confirmedAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: 'Error al cargar',
                    message: e.toString(),
                    actionLabel: 'Reintentar',
                    onAction: () => ref.refresh(confirmedMatchesProvider),
                  ),
                ),
              ),
              data: (matches) {
                if (matches.isEmpty) {
                  return Stack(
                    children: [
                      Center(
                        child: EmptyState(
                          icon: Icons.favorite_border,
                          title: 'Aún no tienes matches',
                          message:
                              'Cuando tú y otra persona se gusten, aparecerán aquí para chatear.',
                          actionLabel: null,
                          onAction: null,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: const _ResetButton(),
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final match = matches[index];
                          return _MatchGridItem(match: match);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: const _ResetButton(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetButton extends ConsumerStatefulWidget {
  const _ResetButton({super.key});

  @override
  ConsumerState<_ResetButton> createState() => _ResetButtonState();
}

class _ResetButtonState extends ConsumerState<_ResetButton> {
  bool _isLoading = false;

  Future<void> _confirmReset(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reiniciar matches?'),
        content: const Text(
          'Esto borrará TODOS tus matches, conversaciones y likes enviados. '
          'Volverás a ver a las personas que ya pasaste o diste like.\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);

      try {
        final success = await MatchesApi.resetMatches();
        if (success) {
          // Prompt 5: Comprehensive state cleanup
          ref.invalidate(confirmedMatchesProvider);
          ref.invalidate(chatsListProvider);
          ref.invalidate(matchesListProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(quizStatusProvider);

          // Force refresh discovery feed to show users again
          ref
              .read(discoverProvider.notifier)
              .loadCandidates(forceRefresh: true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Matches reiniciados con éxito'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo completar el reinicio')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Error: ${e.toString().replaceAll('Exception: ', '')}')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const CircularProgressIndicator(color: Colors.white70)
        : TextButton.icon(
            onPressed: () => _confirmReset(context),
            icon: Icon(Icons.delete_forever,
                color: Colors.white.withOpacity(0.7)),
            label: Text(
              'Borrar todo y empezar de nuevo',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              backgroundColor: Colors.black26,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          );
  }
}

class _MatchGridItem extends StatelessWidget {
  final MatchCandidate match;

  const _MatchGridItem({required this.match});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MatchDetailScreen(candidate: match),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              match.photoUrl != null
                  ? Image.network(
                      match.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade800,
                        child: const Icon(Icons.person,
                            color: Colors.white70, size: 40),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.person,
                          color: Colors.white70, size: 40),
                    ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),

              // Info
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      match.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (match.city.isNotEmpty)
                      Text(
                        match.city,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Open Chat Action (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
