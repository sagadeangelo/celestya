// lib/screens/matches_screen.dart
import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flutter/material.dart';
import '../widgets/match_orange_overlay.dart';

// Mock user photo URL (replace with actual user data when auth is implemented)
const String kMockUserPhotoUrl = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1887&auto=format&fit=crop';

class MatchCandidate {
  final String id;
  final String name;
  final int age;
  final String city;
  final String? photoUrl;
  final String? bio;

  const MatchCandidate({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    this.photoUrl,
    this.bio,
  });
}

/// Lista de ejemplo (mock)
const List<MatchCandidate> kMockMatches = [
  MatchCandidate(
    id: '1',
    name: 'Lucía',
    age: 28,
    city: 'Monterrey, N.L.',
    bio: 'Amante de los templos, la música y los viajes cortos de fin de semana.',
    photoUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?q=80&w=1887&auto=format&fit=crop', // Stock photo
  ),
  MatchCandidate(
    id: '2',
    name: 'Ana',
    age: 30,
    city: 'Saltillo, Coah.',
    bio: 'Me gusta servir, hacer ejercicio temprano y leer por las noches.',
    photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=1887&auto=format&fit=crop', // Stock photo
  ),
  MatchCandidate(
    id: '3',
    name: 'María',
    age: 26,
    city: 'García, N.L.',
    bio: 'Disfruto las actividades al aire libre, la familia y los buenos proyectos.',
    photoUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=1887&auto=format&fit=crop', // Stock photo
  ),
  MatchCandidate(
    id: '4',
    name: 'Sofía',
    age: 24,
    city: 'San Pedro, N.L.',
    bio: 'Coffee lover y arquitecta de sueños.',
    photoUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?q=80&w=1887&auto=format&fit=crop',
  ),
];

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  // Lista local para mostrar (se irá consumiendo al hacer swipe)
  final List<MatchCandidate> _candidates = [...kMockMatches];
  
  // Track current card index
  int _currentCardIndex = 0;

  // Import needed for SwiperActivity
  // But since we can't easily see the package file structure and `appinio_swiper.dart` usually exports it, we will try to use dynamic again but with 3 args.
  // OR better, we will define onSwipe (which gives direction) instead of onSwipeEnd if available?
  // Actually, let's look at the error again: "The argument type 'void Function(int, dynamic)' can't be assigned to ... 'void Function(int, int, SwiperActivity)?'."
  // So we MUST match 3 args.
  
  void _onSwipe(int previousIndex, int targetIndex, dynamic activity) {
    // Update current card index
    setState(() {
      _currentCardIndex = targetIndex;
    });
    
    // Check if it was a valid swipe (index changed)
    if (targetIndex != previousIndex && previousIndex < _candidates.length) {
      // Try to detect if it was a right swipe (like)
      final activityStr = activity.toString().toLowerCase();
      
      // If the activity string contains "right", it's a like
      // Show the match animation
      if (activityStr.contains('right')) {
        final candidate = _candidates[previousIndex];
        _handleLike(candidate);
      }
    }
  }

  void _handleLike(MatchCandidate m) {
    // Show the match animation
    showMatchAnimation(
      context: context,
      userPhotoUrl: kMockUserPhotoUrl,
      matchPhotoUrl: m.photoUrl ?? '',
      matchName: m.name,
    );
  }

  void _onEnd() {
    // Cuando se acaban las cartas
    setState(() {
       // Podríamos recargar o mostrar 'Empty state'
    });
  }
  
  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay candidatos, mostramos "Empty State"
    // (AppinioSwiper oculta cuando no hay items, pero mejor controlarlo)
    if (_candidates.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("¡Has visto a todos por hoy!")),
      );
    }

    return Scaffold(
      // Extendemos cuerpo detrás de AppBar para efecto inmersivo si quisiéramos
      // appBar: AppBar(title: const Text('Descubrir'), backgroundColor: Colors.transparent, elevation: 0),
      // Mejor un SafeArea con un header custom o AppBar estándar.
      appBar: AppBar(
        title: const Text('Celestya'),
        leading: IconButton(
           icon: const Icon(Icons.tune_rounded),
           onPressed: () {}, // Filtros
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
                  controller: _swiperController,
                  cardCount: _candidates.length,
                  onSwipeEnd: _onSwipe,
                  onEnd: _onEnd,
                  swipeOptions: const SwipeOptions.only(
                    left: true, // Nope
                    right: true, // Like
                    up: false, // Superlike?
                    down: false,
                  ),
                  backgroundCardCount: 2, // Cuantas cartas se ven atrás
                  cardBuilder: (context, index) {
                    return _PremiumMatchCard(candidate: _candidates[index]);
                  },
                ),
              ),
            ),
          ),
          
          // Botones de acción (Floating Style)
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
                  size: 75, // Like button bigger
                   // Efecto de sombra glowy
                  isPrimary: true,
                  onPressed: () {
                    // Get current candidate before swiping
                    if (_currentCardIndex >= 0 && _currentCardIndex < _candidates.length) {
                      _handleLike(_candidates[_currentCardIndex]);
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
                     // Superlike feature futura
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

class _PremiumMatchCard extends StatelessWidget {
  final MatchCandidate candidate;

  const _PremiumMatchCard({required this.candidate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Imagen de fondo
            if (candidate.photoUrl != null) 
              Image.network(
                candidate.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200),
              )
            else
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(child: Icon(Icons.person, size: 80, color: theme.colorScheme.primary)),
              ),
            
            // 2. Gradiente Oscuro inferior para legibilidad
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.5, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            
            // 3. Info del usuario (Nombre, Edad, Bio)
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                       Text(
                        candidate.name,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${candidate.age}',
                         style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Ubicación con icono
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        candidate.city,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  if (candidate.bio != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      candidate.bio!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // 4. Botón de "Info" (opcional, esquina superior derecha)
            Positioned(
              right: 16,
              bottom: 110, // Arriba del texto aprox
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () {
                  // Abrir perfil completo
                },
              ),
            ),
          ],
        ),
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
