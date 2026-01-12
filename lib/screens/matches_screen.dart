// lib/screens/matches_screen.dart
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/match_candidate.dart';
import '../features/matching/presentation/providers/filter_provider.dart';
import '../features/matching/presentation/widgets/filter_bottom_sheet.dart';
import '../widgets/match_orange_overlay.dart';
import '../widgets/premium_match_card.dart';
import '../widgets/empty_state.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';

// Mock user photo URL
const String kMockUserPhotoUrl = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1887&auto=format&fit=crop';

/// Lista de ejemplo (mock) extendida
const List<MatchCandidate> kMockMatches = [
  MatchCandidate(
    id: '1',
    name: 'Lucía',
    age: 28,
    city: 'Monterrey, N.L.',
    bio: 'Amante de los templos, la música y los viajes cortos de fin de semana.',
    photoUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?q=80&w=1887&auto=format&fit=crop',
    height: 168,
    exercise: 'Regular',
    interests: ['🎵 Música', '✈️ Viajes', '📚 Lectura'],
    compatibility: 0.95, 
    bodyType: 'Atlética / Tonificada 🏃',
  ),
  MatchCandidate(
    id: '2',
    name: 'Ana',
    age: 30,
    city: 'Saltillo, Coah.',
    bio: 'Me gusta servir, hacer ejercicio temprano y leer por las noches.',
    photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=1887&auto=format&fit=crop',
    height: 172,
    exercise: 'Diario',
    interests: ['🏋️ Ejercicio', '📚 Lectura', '🍳 Cocina'],
    compatibility: 0.80,
    bodyType: 'Promedio ⚖️',
  ),
  MatchCandidate(
    id: '3',
    name: 'María',
    age: 26,
    city: 'García, N.L.',
    bio: 'Disfruto las actividades al aire libre, la familia y los buenos proyectos.',
    photoUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=1887&auto=format&fit=crop',
    height: 160,
    exercise: 'Ocasional',
    interests: ['🏔️ Aire Libre', '🎨 Arte', '🐶 Mascotas'],
    compatibility: 0.60,
    bodyType: 'Con Curvas / Robusto 🍑',
  ),
  MatchCandidate(
    id: '4',
    name: 'Sofía',
    age: 24,
    city: 'San Pedro, N.L.',
    bio: 'Coffee lover y arquitecta de sueños.',
    photoUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?q=80&w=1887&auto=format&fit=crop',
    height: 165,
    exercise: 'Regular',
    interests: ['☕ Café', '🎨 Arte', '✈️ Viajes'],
    compatibility: 0.88,
    bodyType: 'Fuera de mi talla ✨',
  ),
];

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  // Lista base
  final List<MatchCandidate> _allCandidates = [...kMockMatches];
  
  // Track current card index
  int _currentCardIndex = 0;
  
  // Track horizontal delta for overlays
  double _swipeOffset = 0;

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  void _onSwipe(int previousIndex, int targetIndex, dynamic activity) {
    // Nota: Como la lista cambia según los filtros, el índice podría desfasarse si no se maneja
    // la recarga completa del widget (que hacemos con la Key en AppinioSwiper).
    // Por simplicidad en este mock, actualizamos el índice local.
    setState(() {
      _currentCardIndex = targetIndex;
    });
    
    // Detectar swipe derecho (Like)
    // Aquí es complejo saber qué candidato exacto fue swiped si la lista filtered cambia dinámicamente
    // y AppinioSwiper no nos da el objeto, sino índices.
    // Sin embargo, como reconstruimos el Swiper al filtrar, el índice 0 siempre es el visualizado.
    // Para simplificar, asumiremos que la lógica de "Like" se dispara visualmente.
    
    if (targetIndex != previousIndex) {
      final activityStr = activity.toString().toLowerCase();
      if (activityStr.contains('right')) {
         // En un escenario real, recuperaríamos el candidato de la lista FILTRADA actual.
         // Pero como setState reconstruye, necesitamos persistir la lista filtrada fuera del build o calcularla.
         // Para este demo visual, dejaremos la animación en el botón explícito.
      }
    }
  }

  void _handleLike(MatchCandidate m) {
    showMatchAnimation(
      context: context,
      userPhotoUrl: kMockUserPhotoUrl,
      matchPhotoUrl: m.photoUrl ?? '',
      matchName: m.name,
    );
  }

  void _onEnd() {
    setState(() {
       // Fin de la pila
    });
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(filterProvider);

    // Aplicar filtros a la lista base
    final filteredCandidates = _allCandidates.where((c) {
      // 1. Edad
      // 1. Edad
      if (c.age != null && (c.age! < filters.ageRange.start || c.age! > filters.ageRange.end)) return false;
      
      // 2. Altura
      if (filters.minHeight != null && c.height < filters.minHeight!) return false;

      // 3. Ejercicio
      if (filters.exerciseFrequency != null && c.exercise != filters.exerciseFrequency) return false;

      // 4. Complexión (Nuevo)
      if (filters.bodyTypes.isNotEmpty) {
        if (c.bodyType == null || !filters.bodyTypes.contains(c.bodyType)) {
          return false;
        }
      }

      // 4. Intereses (Match al menos uno)
      if (filters.selectedInterests.isNotEmpty) {
        final hasCommonInterest = c.interests.any((i) => filters.selectedInterests.contains(i));
        if (!hasCommonInterest) return false;
      }

      return true;
    }).toList();

    // Pantalla de "Sin resultados"
    // Pantalla de "Sin resultados" (Empty State Theme)
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
             // 1. Background Gradient
            Container(
              decoration: BoxDecoration( // Removed const
                gradient: CelestyaColors.softSpaceGradient,
              ),
            ),
            // 2. Calming Starry Sky
            Positioned.fill( // Removed const
              child: StarryBackground(
                numberOfStars: 100, // Gentle amount
                baseColor: Color(0xFFE0E0E0),
              ),
            ),
            // 3. Content
            Center(
              child: EmptyState(
                icon: Icons.hourglass_empty_rounded,
                title: 'Las conexiones importantes toman tiempo',
                message: 'El universo está alineando las estrellas.\nMientras tanto, puedes ajustar tus preferencias.',
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
        title: const Text('Celestya', style: TextStyle(fontWeight: FontWeight.w300)),
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
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {}, 
          )
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient to ensure consistency
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

          // Card Stack
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(top: 0), // Full height
              child: AppinioSwiper(
                key: ValueKey(filteredCandidates.length + filters.hashCode),
                controller: _swiperController,
                cardCount: filteredCandidates.length,
                onSwipeEnd: (prev, target, activity) {
                   _onSwipe(prev, target, activity);
                   // Haptic Feedback Light
                   HapticFeedback.lightImpact();
                   setState(() {
                     _swipeOffset = 0;
                   });
                },
                onEnd: _onEnd,
                swipeOptions: const SwipeOptions.only(
                  left: true,
                  right: true,
                  up: false,
                  down: false,
                ),
                backgroundCardCount: 2,
                onCardPositionChanged: (position) {
                  setState(() {
                    _swipeOffset = position.offset.dx;
                  });
                },
                onSwipeCancelled: (activity) {
                  setState(() => _swipeOffset = 0);
                },
                cardBuilder: (context, index) {
                  if (index >= filteredCandidates.length) return const SizedBox();
                  
                  final card = PremiumMatchCard(candidate: filteredCandidates[index]);
                  
                  // Solo mostrar overlay en la tarjeta que se está moviendo (la de arriba)
                  final bool isTopCard = index == (filteredCandidates.length - 1 - _currentCardIndex);
                  // En AppinioSwiper, el index del cardBuilder suele ser el índice de la lista.
                  // Pero como queremos el overlay solo en el que se mueve, y el swiper suele renderizar 
                  // los que están visibles, asumiremos que si index == 0 (el primero que se construye para el stack activo)
                  
                  // Para mayor seguridad en AppinioSwiper v2, el top card suele ser el índice 0 si se usa cardBuilder simple,
                  // pero vamos a probar con index == 0.
                  
                  final double opacity = (_swipeOffset.abs() / 150).clamp(0.0, 0.8);
                  final bool isRight = _swipeOffset > 10;
                  final bool isLeft = _swipeOffset < -10;

                  return Stack(
                    children: [
                      card,
                      if ((isRight || isLeft) && index == 0) // Overlay solo en el actual
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
                                    size: 100, // Slightly smaller to be more elegant
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
          ),
          
          // Action Buttons (Floating at bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center, // Fixed alignment
              children: [
                _ActionButton(
                  icon: Icons.close_rounded,
                  color: const Color(0xFFFF4B4B), // Red
                  size: 60,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _swiperController.swipeLeft();
                  },
                ),
                
                // Pulsing Heart Button
                _PulsingHeartButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    if (filteredCandidates.isNotEmpty) {
                      _handleLike(filteredCandidates[0]); 
                    }
                    _swiperController.swipeRight();
                  },
                ),

                _ActionButton(
                  icon: Icons.star_rounded,
                  color: const Color(0xFF62BAF3), // Blue
                  size: 50,
                  onPressed: () {
                     HapticFeedback.selectionClick();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Superlike pronto...")));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
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
          color: Colors.white.withOpacity(0.1), // Glass effect
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color, // Icon color keeps vibrancy
          size: size * 0.45,
        ),
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

class _PulsingHeartButtonState extends State<_PulsingHeartButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Slow, calm pulse
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
        final scale = 1.0 + (_controller.value * 0.1); // Subtle breathing (1.0 -> 1.1)
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
                  colors: [Color(0xFFFF006E), Color(0xFFFFBE0B)], // Nebula Pink to Gold
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
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        );
      },
    );
  }
}
