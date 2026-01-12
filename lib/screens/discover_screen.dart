import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with TickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;
  
  late AnimationController _textController;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  
  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;

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

    // Text Entrance Animation (One-shot)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Title: Starts at 0.3 (450ms)
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
    
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );

    // Subtitle: Starts at 0.6 (900ms) - Staggered ~450ms after title
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
       CurvedAnimation(parent: _textController, curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic)),
    );

    _textController.forward();
  }

  @override
  void dispose() {
    _heartController.dispose();
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
            // Pulsing Heart
            AnimatedBuilder(
              animation: _heartController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _heartAnimation.value,
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: CelestyaColors.auroraTeal.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: CelestyaColors.nebulaPink.withOpacity(0.2), // Subtle pink mix
                      blurRadius: 20,
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith( // Reduced from headlineMedium
                        color: CelestyaColors.deepNight.withOpacity(0.6),
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    ShaderMask(
                      shaderCallback: (bounds) => CelestyaColors.mainGradient.createShader(bounds),
                      child: Text(
                        'Celestya',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith( // Reduced from displayLarge
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // More space for the hero phrase
                    
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
                               Color(0xFFB89307), // Slightly more muted/deeper gold
                               CelestyaColors.deepNight
                             ], 
                             stops: [0.0, 0.5, 1.0],
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                           ).createShader(bounds),
                           child: Text(
                            '"Donde las conexiones se vuelven eternas"',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white, // Masked
                              fontSize: 16, // Slightly smaller as requested
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              letterSpacing: 0.8,
                              height: 1.3,
                              shadows: [
                                Shadow(
                                  color: CelestyaColors.starlightGold.withOpacity(0.4),
                                  blurRadius: 6, // Adjusted blur for smaller text
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            ),
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
