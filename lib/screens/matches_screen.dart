// lib/screens/matches_screen.dart
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/match_candidate.dart';

import '../features/matching/presentation/widgets/filter_bottom_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/premium_match_card.dart';
import '../widgets/starry_background.dart';
import '../theme/app_theme.dart';

import '../services/matches_api.dart';
import '../widgets/match_orange_overlay.dart';
import '../features/profile/presentation/providers/profile_provider.dart';

// Mock user photo URL (para animación de match, cámbialo luego por tu foto real)
const String kMockUserPhotoUrl =
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1887&auto=format&fit=crop';

/// Provider: carga MATCHES CONFIRMADOS desde backend
final confirmedMatchesProvider =
    FutureProvider.autoDispose<List<MatchCandidate>>((ref) async {
  return MatchesApi.getConfirmed();
});

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  int _activeIndex = 0; // índice del card actualmente “top”
  double _swipeOffset = 0;

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  void _handleLike(MatchCandidate m) {
    // Get current user profile
    final userProfile = ref.read(profileProvider).asData?.value;
    final userPhotoUrl = userProfile?.photoUrls.firstOrNull ?? '';

    try {
      // ignore: undefined_function
      showMatchAnimation(
        context: context,
        userPhotoUrl:
            userPhotoUrl.isNotEmpty ? userPhotoUrl : kMockUserPhotoUrl,
        matchPhotoUrl: m.photoUrl ?? '',
        matchName: m.name,
      );
    } catch (_) {}
  }

  // REMOVED: Filter logic no longer needed in MatchesScreen
  // MatchesScreen shows ONLY confirmed matches, no filtering required

  @override
  Widget build(BuildContext context) {
    final confirmedAsync = ref.watch(confirmedMatchesProvider);

    return confirmedAsync.when(
      loading: () => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => _showFilters(context),
          ),
        ),
        body: Stack(
          children: [
            Container(
                decoration:
                    BoxDecoration(gradient: CelestyaColors.softSpaceGradient)),
            const Positioned.fill(
              child: StarryBackground(
                numberOfStars: 120,
                baseColor: Color(0xFFE0E0E0),
              ),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      error: (e, _) => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
            onPressed: () => _showFilters(context),
          ),
        ),
        body: Stack(
          children: [
            Container(
                decoration:
                    BoxDecoration(gradient: CelestyaColors.softSpaceGradient)),
            const Positioned.fill(
              child: StarryBackground(
                  numberOfStars: 120, baseColor: Color(0xFFE0E0E0)),
            ),
            Center(
              child: EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'No pudimos cargar sugerencias',
                message: 'Revisa tu conexión o el backend.\n\nError: $e',
                actionLabel: 'Reintentar',
                onAction: () => ref.refresh(confirmedMatchesProvider),
              ),
            ),
          ],
        ),
      ),
      data: (confirmedMatches) {
        // No filtering - just show confirmed matches as-is

        if (confirmedMatches.isEmpty) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              // No filter button
            ),
            body: Stack(
              children: [
                Container(
                    decoration: BoxDecoration(
                        gradient: CelestyaColors.softSpaceGradient)),
                const Positioned.fill(
                  child: StarryBackground(
                      numberOfStars: 100, baseColor: Color(0xFFE0E0E0)),
                ),
                Center(
                  child: EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Aún no tienes matches',
                    message:
                        'Ve a Descubrir para encontrar personas que te gusten.\nCuando haya un match mutuo, aparecerán aquí.',
                    actionLabel: null,
                    onAction: null,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Matches',
                style: TextStyle(fontWeight: FontWeight.w300)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            // No filter button for confirmed matches
            actions: [
              IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black12),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () => ref.refresh(confirmedMatchesProvider),
              ),
            ],
          ),
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                    stops: [0.0, 0.3],
                  ),
                ),
              ),
              Positioned.fill(
                child: AppinioSwiper(
                  key: ValueKey(confirmedMatches.length),
                  controller: _swiperController,
                  cardCount: confirmedMatches.length,
                  swipeOptions: const SwipeOptions.only(
                    left: true,
                    right: true,
                    up: false,
                    down: false,
                  ),
                  backgroundCardCount: 2,
                  onCardPositionChanged: (position) {
                    setState(() => _swipeOffset = position.offset.dx);
                  },
                  onSwipeCancelled: (_) => setState(() => _swipeOffset = 0),
                  onSwipeEnd: (prev, target, activity) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _activeIndex = target;
                      _swipeOffset = 0;
                    });

                    // Si fue swipe right, puedes disparar animación
                    final act = activity.toString().toLowerCase();
                    if (act.contains('right')) {
                      final swiped =
                          (prev >= 0 && prev < confirmedMatches.length)
                              ? confirmedMatches[prev]
                              : null;
                      if (swiped != null) _handleLike(swiped);
                    }
                  },
                  onEnd: () {
                    // Si se acabó el stack, recarga
                    ref.refresh(confirmedMatchesProvider);
                  },
                  cardBuilder: (context, index) {
                    final candidate = confirmedMatches[index];
                    final card = PremiumMatchCard(candidate: candidate);

                    final double opacity =
                        (_swipeOffset.abs() / 150).clamp(0.0, 0.8);
                    final bool isRight = _swipeOffset > 10;
                    final bool isLeft = _swipeOffset < -10;

                    // Overlay solo para la carta activa
                    final bool isActiveCard = index == _activeIndex;

                    return Stack(
                      children: [
                        card,
                        if (isActiveCard && (isRight || isLeft))
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: opacity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    color: isRight
                                        ? Colors.green.withOpacity(0.3)
                                        : Colors.red.withOpacity(0.3),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isRight
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.cancel_outlined,
                                      size: 100,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 15,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.close_rounded,
                      color: const Color(0xFFFF4B4B),
                      size: 60,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _swiperController.swipeLeft();
                      },
                    ),
                    _PulsingHeartButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        final current = (_activeIndex >= 0 &&
                                _activeIndex < confirmedMatches.length)
                            ? confirmedMatches[_activeIndex]
                            : null;
                        if (current != null) _handleLike(current);
                        _swiperController.swipeRight();
                      },
                    ),
                    _ActionButton(
                      icon: Icons.star_rounded,
                      color: const Color(0xFF62BAF3),
                      size: 50,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Superlike pronto...")),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }
}

class _PulsingHeartButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _PulsingHeartButton({required this.onPressed});

  @override
  State<_PulsingHeartButton> createState() => _PulsingHeartButtonState();
}

class _PulsingHeartButtonState extends State<_PulsingHeartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.1);
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF006E), Color(0xFFFFBE0B)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF006E).withOpacity(0.4),
                    blurRadius: 20 * scale,
                    spreadRadius: 2 * scale,
                  ),
                ],
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 36),
            ),
          ),
        );
      },
    );
  }
}
