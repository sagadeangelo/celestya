// lib/widgets/match_orange_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Custom clipper that creates a perfect half-circle
class CircleHalfClipper extends CustomClipper<Path> {
  final bool isLeftHalf;

  const CircleHalfClipper({required this.isLeftHalf});

  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = size.height / 2; // El radio es la mitad de la altura
    final center = Offset(size.width / 2, size.height / 2);

    if (isLeftHalf) {
      // Mitad izquierda del círculo
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi / 2, // Empieza desde abajo
        math.pi, // Recorre 180 grados (medio círculo)
      );
      path.lineTo(center.dx, size.height); // Línea al centro abajo
      path.lineTo(center.dx, 0); // Línea al centro arriba
      path.close();
    } else {
      // Mitad derecha del círculo
      path.addArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Empieza desde arriba
        math.pi, // Recorre 180 grados (medio círculo)
      );
      path.lineTo(center.dx, 0); // Línea al centro arriba
      path.lineTo(center.dx, size.height); // Línea al centro abajo
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(CircleHalfClipper oldClipper) => false;
}

/// Painter for confetti particles
class ConfettiPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_ConfettiParticle> particles;

  ConfettiPainter({
    required this.animation,
    required this.particles,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;

    for (final particle in particles) {
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      final x = particle.startX + particle.velocityX * progress * size.width;
      final y = particle.startY +
          particle.velocityY * progress * size.height +
          0.5 * 500 * progress * progress; // Gravity effect

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation * progress * 2 * math.pi);

      // Draw particle as a small heart or circle
      canvas.drawCircle(Offset.zero, 4, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}

class _ConfettiParticle {
  final double startX;
  final double startY;
  final double velocityX;
  final double velocityY;
  final Color color;
  final double rotation;

  _ConfettiParticle({
    required this.startX,
    required this.startY,
    required this.velocityX,
    required this.velocityY,
    required this.color,
    required this.rotation,
  });
}

/// Full-screen overlay that shows the "It's a Match" animation (Pink/Purple style)
class MatchOrangeOverlay extends StatefulWidget {
  final String userPhotoUrl;
  final String matchPhotoUrl;
  final String matchName;

  const MatchOrangeOverlay({
    super.key,
    required this.userPhotoUrl,
    required this.matchPhotoUrl,
    required this.matchName,
  });

  @override
  State<MatchOrangeOverlay> createState() => _MatchOrangeOverlayState();
}

class _MatchOrangeOverlayState extends State<MatchOrangeOverlay>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _confettiController;

  late Animation<Offset> _leftSlideAnimation;
  late Animation<Offset> _rightSlideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  late List<_ConfettiParticle> _confettiParticles;

  @override
  void initState() {
    super.initState();

    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Confetti animation controller
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Left half slides in from left
    _leftSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutBack,
      ),
    );

    // Right half slides in from right
    _rightSlideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutBack,
      ),
    );

    // Text fade in
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
      ),
    );

    // Pulse effect
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Generate confetti particles
    _confettiParticles = _generateConfetti();

    // Start animations
    _slideController.forward().then((_) {
      _pulseController.repeat(reverse: true);
      _confettiController.forward();
    });
  }

  List<_ConfettiParticle> _generateConfetti() {
    final random = math.Random();
    final colors = [
      CelestyaColors.nebulaPink,
      CelestyaColors.mysticalPurple,
      CelestyaColors.starlightGold,
      Colors.white,
    ];

    return List.generate(40, (index) {
      return _ConfettiParticle(
        startX: 0.3 + random.nextDouble() * 0.4, // Center area
        startY: 0.3 + random.nextDouble() * 0.2,
        velocityX: -0.3 + random.nextDouble() * 0.6,
        velocityY: -0.5 - random.nextDouble() * 0.5,
        color: colors[random.nextInt(colors.length)],
        rotation: random.nextDouble(),
      );
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Un poco más chico para evitar overflow en pantallas pequeñas
    final circleSize = math.min(size.width * 0.7, size.height * 0.35);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Background Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black,
                      CelestyaColors.nebulaPink.withOpacity(0.2),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),

            // Confetti layer
            Positioned.fill(
              child: CustomPaint(
                painter: ConfettiPainter(
                  animation: _confettiController,
                  particles: _confettiParticles,
                ),
              ),
            ),

            // Main content
            Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Circles (User + Match)
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: SizedBox(
                            width: circleSize,
                            height: circleSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Heart/Circle GLOW
                                Container(
                                  width: circleSize,
                                  height: circleSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: CelestyaColors.nebulaPink
                                            .withOpacity(0.6),
                                        blurRadius: 50,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),

                                // Left half (user)
                                SlideTransition(
                                  position: _leftSlideAnimation,
                                  child: _ProfileHalf(
                                    photoUrl: widget.userPhotoUrl,
                                    isLeftHalf: true,
                                    size: circleSize,
                                  ),
                                ),

                                // Right half (match)
                                SlideTransition(
                                  position: _rightSlideAnimation,
                                  child: _ProfileHalf(
                                    photoUrl: widget.matchPhotoUrl,
                                    isLeftHalf: false,
                                    size: circleSize,
                                  ),
                                ),

                                // ICONS / HEART CENTER
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: CelestyaColors.nebulaPink
                                              .withOpacity(0.5),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        )
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: CelestyaColors.nebulaPink,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 48),

                    // "It's a Match!" Text
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            "It's a Match!",
                            style: TextStyle(
                              fontFamily: 'Pacifico', // O la fuente que uses
                              fontSize: 48,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 20,
                                  color: CelestyaColors.nebulaPink,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tú y ${widget.matchName} se gustaron mutuamente',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                          ),
                          const SizedBox(height: 40),

                          // Action Buttons
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: CelestyaColors.nebulaPink,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'ENVIAR MENSAJE',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('SEGUIR DESCUBRIENDO',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ],
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

/// Widget that represents one half of the profile circle
class _ProfileHalf extends StatelessWidget {
  final String photoUrl;
  final bool isLeftHalf;
  final double size;

  const _ProfileHalf({
    required this.photoUrl,
    required this.isLeftHalf,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: CircleHalfClipper(isLeftHalf: isLeftHalf),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PROFILE PHOTO
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade800,
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),

            // OVERLAY GRADIENT
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:
                      isLeftHalf ? Alignment.centerLeft : Alignment.centerRight,
                  end:
                      isLeftHalf ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    CelestyaColors.nebulaPink.withOpacity(0.3),
                    CelestyaColors.mysticalPurple.withOpacity(0.1),
                  ],
                ),
              ),
            ),

            // BORDER LINE (Inner)
            CustomPaint(
              painter: _BorderPainter(isLeftHalf: isLeftHalf),
            ),
          ],
        ),
      ),
    );
  }
}

class _BorderPainter extends CustomPainter {
  final bool isLeftHalf;

  _BorderPainter({required this.isLeftHalf});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    if (isLeftHalf) {
      canvas.drawArc(rect, math.pi / 2, math.pi, false, paint);
    } else {
      canvas.drawArc(rect, -math.pi / 2, math.pi, false, paint);
    }
  }

  @override
  bool shouldRepaint(_BorderPainter oldDelegate) => false;
}

/// Helper function to show the match animation
Future<void> showMatchAnimation({
  required BuildContext context,
  required String userPhotoUrl,
  required String matchPhotoUrl,
  required String matchName,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return MatchOrangeOverlay(
          userPhotoUrl: userPhotoUrl,
          matchPhotoUrl: matchPhotoUrl,
          matchName: matchName,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    ),
  );
}
