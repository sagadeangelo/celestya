import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/navigation_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with TickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;

  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;

  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();

    // Heartbeat Animation (Continuous, Soft)
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _heartAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeInOutSine),
    );

    // Ripple Animation (Continuous, Expanding)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Text Entrance Animation (One-shot)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Extended for guide text
    );

    // Title: Starts at 0.3 (450ms)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _textController,
          curve: const Interval(0.2, 0.6, curve: Curves.easeOut)),
    );

    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _textController,
          curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic)),
    );

    // Subtitle: Starts at 0.6 (900ms)
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _textController,
          curve: const Interval(0.5, 0.8, curve: Curves.easeOut)),
    );

    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _textController,
          curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic)),
    );

    _textController.forward();
  }

  @override
  void dispose() {
    _heartController.dispose();
    _rippleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // Diffused Aqua Gradient
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CelestyaColors.auroraTeal.withOpacity(0.15), // Very soft aqua
              Colors.white, // Fades to white for cleanliness
            ],
            stops: const [0.0, 0.6],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radar/Ripple + Pulsing Heart
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Ripples behind
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _rippleController,
                    builder: (context, child) {
                      final progress =
                          (_rippleController.value + (index / 3)) % 1.0;
                      final scale = 1.0 + (progress * 1.5); // Grow to 2.5x
                      final opacity = (1.0 - progress).clamp(0.0, 1.0);

                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width:
                              100, // Base size same as heart container roughly
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CelestyaColors.auroraTeal
                                  .withOpacity(opacity * 0.5),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),

                // Main Heart Button
                GestureDetector(
                  onTap: () {
                    final profileState = ref.watch(profileProvider);
                    profileState.when(
                      data: (profile) {
                        if (profile.isProfileComplete) {
                          // Navigate to Matches (Index 1)
                          ref.read(navIndexProvider.notifier).state = 1;
                        } else {
                          // Show message and take to profile
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Completa tu perfil (Nombre, Ciudad y Foto) para comenzar a descubrir personas.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          ref.read(navIndexProvider.notifier).state =
                              3; // Profile Index
                        }
                      },
                      loading: () {},
                      error: (_, __) =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Error al verificar perfil')),
                      ),
                    );
                  },
                  child: AnimatedBuilder(
                    animation: _heartController,
                    builder: (context, child) {
                      final profileState = ref.watch(profileProvider);
                      final bool isLocked = profileState.maybeWhen(
                        data: (p) => !p.isProfileComplete,
                        orElse: () => true,
                      );

                      return Transform.scale(
                        scale: _heartAnimation.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            child!,
                            if (isLocked)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 24,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: CelestyaColors.auroraTeal.withOpacity(0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 80,
                        color: CelestyaColors.nebulaPink,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Guide Text
            FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                      parent: _textController,
                      curve: const Interval(0.8, 1.0, curve: Curves.easeIn))),
              child: Text(
                "Toca para conectar",
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      // Reduced to labelMedium (subtle)
                      color: CelestyaColors.deepNight.withOpacity(0.5),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w400, // Lighter
                    ),
              ),
            ),

            const SizedBox(height: 40),

            // Welcome Text
            FadeTransition(
              opacity: _textOpacity,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  children: [
                    Text(
                      'Bienvenido a',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            // Reduced to titleMedium
                            color: CelestyaColors.deepNight.withOpacity(0.6),
                            fontWeight: FontWeight.w300,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          CelestyaColors.mainGradient.createShader(bounds),
                      child: Text(
                        'Celestya',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  // Reduced to displaySmall
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                      ),
                    ),
                    const SizedBox(
                        height: 24), // More space for the hero phrase

                    // Subtitle Animation (The Hero)
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: SlideTransition(
                        position: _subtitleSlide,
                        child: ShaderMask(
                          // Muted Golden/Eternal Gradient (More subtle)
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              CelestyaColors.deepNight,
                              Color(
                                  0xFFB89307), // Slightly more muted/deeper gold
                              CelestyaColors.deepNight
                            ],
                            stops: [0.0, 0.5, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            '"Donde las conexiones se vuelven eternas"',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    // Bumped back to titleMedium
                                    color: Colors.white, // Masked
                                    fontSize:
                                        16, // Increased to 16 as requested
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                    letterSpacing: 0.8,
                                    height: 1.3,
                                    shadows: [
                                  Shadow(
                                    color: CelestyaColors.starlightGold
                                        .withOpacity(0.4),
                                    blurRadius:
                                        6, // Adjusted blur for smaller text
                                    offset: const Offset(0, 1),
                                  ),
                                ]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
