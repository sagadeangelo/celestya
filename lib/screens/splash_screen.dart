import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rotationController;
  late AnimationController _pulseController; // New for continuous breathing
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _pulseAnimation; // New pulse animation

  @override
  void initState() {
    super.initState();
    // Ocultar barra de estado para inmersión total
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Eclipse Light Rotation
    _rotationController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 3),
    )..repeat();

    // Subtle Continuous Pulse (Breathing)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Breathing effect - animación de escala suave
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navegar después de 3 segundos
    Future.delayed(const Duration(seconds: 3), () async {
      if (mounted) {
        // Restaurar UI overlay
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

        // Check onboarding status
        final prefs = await SharedPreferences.getInstance();
        final seenOnboarding = prefs.getBool('onboarding_completed') ?? false;
        
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => seenOnboarding ? const AuthGate() : const OnboardingScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: CelestyaColors.spaceBlack, // Base
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Color(0xFF2E1C4E), // Diffused Purple (Nebula Core)
              CelestyaColors.spaceBlack,
            ],
            stops: [0.0, 0.8],
          ),
          image: null, // Could add star pattern here later
        ),
        child: Container(
          decoration: BoxDecoration(
             gradient: LinearGradient(
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter,
               colors: [
                 CelestyaColors.celestialBlue.withOpacity(0.15), // Soft diffused blue veil
                 Colors.transparent,
               ],
             )
          ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo con Luz Circundante
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                    // 1. Luz Circundante (Eclipse Ring)
                    RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 208, // Thinner ring (208 vs 200 logo = 4px visible border)
                        height: 208,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFFC0C0C0).withOpacity(0.0), // Silver start
                              const Color(0xFFE0E0E0), // Bright Silver head
                              Colors.white, // Core of the light (Luminosity)
                              const Color(0xFFE0E0E0), // Silver tail
                              const Color(0xFFC0C0C0).withOpacity(0.0),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.7, 0.85, 0.9, 0.95, 1.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                    
                    // 2. Logo Central
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF9B5CFF).withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/app_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
                const SizedBox(height: 32),
                // Nombre con gradiente
                const Text(
                  'Celestya',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                Text(
                  'Tu media naranja te espera ✨',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
       ),
      ),
    );
  }
}
