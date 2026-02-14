// lib/screens/matches_screen.dart
import 'dart:math' as math;
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/match_candidate.dart';
import '../features/matching/presentation/providers/filter_provider.dart';
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

/// Provider: carga sugerencias desde backend
final suggestedMatchesProvider =
    FutureProvider.autoDispose<List<MatchCandidate>>((ref) async {
  return MatchesApi.getSuggested();
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
    // Si tu función showMatchAnimation vive en otro archivo, déjala igual.
    // Aquí solo la llamamos si existe en tu proyecto.
    try {
      // ignore: undefined_function
      showMatchAnimation(
        context: context,
        userPhotoUrl: kMockUserPhotoUrl,
        matchPhotoUrl: m.photoUrl ?? '',
        matchName: m.name,
      );
    } catch (_) {}
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  List<MatchCandidate> _applyFilters(List<MatchCandidate> base, dynamic filters,
      double? userLat, double? userLon) {
    return base.where((c) {
      // 0) Distancia (Mundial = 300+)
      if (filters.maxDistance < 300) {
        if (userLat != null &&
            userLon != null &&
            c.latitude != null &&
            c.longitude != null) {
          final dist =
              _calculateDistance(userLat, userLon, c.latitude!, c.longitude!);
          if (dist > filters.maxDistance) return false;
        }
      }

      // 1) Edad
      if (c.age != null &&
          (c.age! < filters.ageRange.start || c.age! > filters.ageRange.end)) {
        return false;
      }

      // 2) Altura
      if (filters.minHeight != null && c.height < filters.minHeight!)
        return false;

      // 3) Ejercicio
      if (filters.exerciseFrequency != null &&
          c.exercise != filters.exerciseFrequency) {
        return false;
      }

      // 4) Complexión
      if (filters.bodyTypes.isNotEmpty) {
        if (c.bodyType == null || !filters.bodyTypes.contains(c.bodyType))
          return false;
      }

      // 5) Estado Civil
      if (filters.maritalStatus.isNotEmpty) {
        if (c.maritalStatus == null ||
            !filters.maritalStatus.contains(c.maritalStatus)) {
          return false;
        }
      }

      // 6) Hijos
      if (filters.childrenPreference != null) {
        if (filters.childrenPreference == 'con_hijos') {
          if (c.hasChildren != true) return false;
        } else if (filters.childrenPreference == 'sin_hijos') {
          if (c.hasChildren != false) return false;
        }
      }

      // 7) Intereses: al menos uno
      if (filters.selectedInterests.isNotEmpty) {
        final hasCommon =
            c.interests.any((i) => filters.selectedInterests.contains(i));
        if (!hasCommon) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(filterProvider);
    final suggestedAsync = ref.watch(suggestedMatchesProvider);

    return suggestedAsync.when(
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
                onAction: () => ref.refresh(suggestedMatchesProvider),
              ),
            ),
          ],
        ),
      ),
      data: (backendCandidates) {
        final profile = ref.watch(profileProvider).value;
        final filteredCandidates = _applyFilters(
          backendCandidates,
          filters,
          profile?.latitude,
          profile?.longitude,
        );

        if (filteredCandidates.isEmpty) {
          return Scaffold(
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
                    decoration: BoxDecoration(
                        gradient: CelestyaColors.softSpaceGradient)),
                const Positioned.fill(
                  child: StarryBackground(
                      numberOfStars: 100, baseColor: Color(0xFFE0E0E0)),
                ),
                Center(
                  child: EmptyState(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'Las conexiones importantes toman tiempo',
                    message:
                        'El universo está alineando las estrellas.\nMientras tanto, puedes ajustar tus preferencias.',
                    actionLabel: 'Ampliar búsqueda',
                    onAction: () => _showFilters(context),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Descubrir',
                style: TextStyle(fontWeight: FontWeight.w300)),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.black12),
              icon: const Icon(Icons.tune_rounded, color: Colors.white),
              onPressed: () => _showFilters(context),
            ),
            actions: [
              IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black12),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () => ref.refresh(suggestedMatchesProvider),
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
                  key: ValueKey(filteredCandidates.length + filters.hashCode),
                  controller: _swiperController,
                  cardCount: filteredCandidates.length,
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
                          (prev >= 0 && prev < filteredCandidates.length)
                              ? filteredCandidates[prev]
                              : null;
                      if (swiped != null) _handleLike(swiped);
                    }
                  },
                  onEnd: () {
                    // Si se acabó el stack, recarga
                    ref.refresh(suggestedMatchesProvider);
                  },
                  cardBuilder: (context, index) {
                    final candidate = filteredCandidates[index];
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
                                _activeIndex < filteredCandidates.length)
                            ? filteredCandidates[_activeIndex]
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
