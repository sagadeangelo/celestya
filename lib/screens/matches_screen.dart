// lib/screens/matches_screen.dart
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/match_candidate.dart';
import '../features/matching/presentation/providers/filter_provider.dart';
import '../features/matching/presentation/widgets/filter_bottom_sheet.dart';
import '../widgets/match_orange_overlay.dart';
import '../widgets/premium_match_card.dart';
import '../widgets/empty_state.dart';

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
    if (filteredCandidates.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Celestya'),
          leading: IconButton(
             icon: const Icon(Icons.tune_rounded),
             onPressed: () => _showFilters(context),
          ),
        ),
        body: EmptyState(
          icon: Icons.search_off,
          title: 'No hay matches con estos filtros',
          message: 'Intenta ajustar tus preferencias para ver más perfiles compatibles',
          actionLabel: 'Limpiar filtros',
          onAction: () => ref.read(filterProvider.notifier).resetFilters(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Celestya'),
        leading: IconButton(
           icon: const Icon(Icons.tune_rounded),
           onPressed: () => _showFilters(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {}, 
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: AppinioSwiper(
                  // Usamos Key para forzar la reconstrucción cuando cambian los filtros
                  key: ValueKey(filteredCandidates.length + filters.hashCode),
                  controller: _swiperController,
                  cardCount: filteredCandidates.length,
                  onSwipeEnd: _onSwipe,
                  onEnd: _onEnd,
                  swipeOptions: const SwipeOptions.only(
                    left: true,
                    right: true,
                    up: false,
                    down: false,
                  ),
                  backgroundCardCount: 2,
                  cardBuilder: (context, index) {
                    if (index >= filteredCandidates.length) return const SizedBox();
                    return PremiumMatchCard(candidate: filteredCandidates[index]);
                  },
                ),
              ),
            ),
          ),
          
          // Botones de acción
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.close,
                  color: Colors.redAccent,
                  size: 60,
                  onPressed: () => _swiperController.swipeLeft(),
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.favorite,
                  color: Theme.of(context).colorScheme.primary,
                  size: 75,
                  isPrimary: true,
                  onPressed: () {
                    // Simulación simplificada de Like para el botón
                    // En lógica real, obtendríamos el item actual del controller
                    if (filteredCandidates.isNotEmpty) {
                      _handleLike(filteredCandidates[0]); 
                    }
                    _swiperController.swipeRight();
                  },
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.star,
                  color: Colors.amber,
                  size: 50,
                  onPressed: () {
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
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.size,
    required this.onPressed,
    this.isPrimary = false,
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isPrimary ? 0.4 : 0.15),
              spreadRadius: isPrimary ? 4 : 1,
              blurRadius: isPrimary ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
