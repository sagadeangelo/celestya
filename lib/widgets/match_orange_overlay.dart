// lib/widgets/match_orange_overlay.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom clipper that creates a half-circle orange slice shape
class OrangeSliceClipper extends CustomClipper<Path> {
  final bool isLeftHalf;

  const OrangeSliceClipper({required this.isLeftHalf});

  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = size.height / 2;

    if (isLeftHalf) {
      // Left half - arc from top to bottom on the left side
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.arcToPoint(
        Offset(0, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      );
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      // Right half - arc from top to bottom on the right side
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.arcToPoint(
        Offset(size.width, size.height),
        radius: Radius.circular(radius),
        clockwise: true,
      );
      path.lineTo(0, size.height);
      path.close();
    }

    return path;
  }

  @override
  bool shouldReclip(OrangeSliceClipper oldClipper) => false;
}

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

      // Draw particle as a small rectangle
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 8, height: 12),
          const Radius.circular(2),
        ),
        paint,
      );

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

/// Full-screen overlay that shows the "Media Naranja" match animation
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
      Colors.pink.shade300,
      Colors.purple.shade300,
      Colors.orange.shade300,
      Colors.yellow.shade300,
      Colors.red.shade300,
    ];

    return List.generate(30, (index) {
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
    final orangeSize = math.min(size.width * 0.7, size.height * 0.35);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
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
                    // Orange halves + naranja real de fondo
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: SizedBox(
                            width: orangeSize,
                            height: orangeSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 🔸 NARANJA REAL DE FONDO (TU IMAGEN)
                                ClipOval(
                                  child: Image.asset(
                                    'assets/orange_texture.png',
                                    width: orangeSize,
                                    height: orangeSize,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                                // Left half (user)
                                SlideTransition(
                                  position: _leftSlideAnimation,
                                  child: _OrangeHalf(
                                    photoUrl: widget.userPhotoUrl,
                                    isLeftHalf: true,
                                    size: orangeSize,
                                  ),
                                ),

                                // Right half (match)
                                SlideTransition(
                                  position: _rightSlideAnimation,
                                  child: _OrangeHalf(
                                    photoUrl: widget.matchPhotoUrl,
                                    isLeftHalf: false,
                                    size: orangeSize,
                                  ),
                                ),

                                // Texto "MATCH" y "¿Tu media naranja?" sobre la naranja
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Texto "MATCH"
                                        Text(
                                          'MATCH',
                                          style: TextStyle(
                                            fontSize: orangeSize * 0.15,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 4,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 20,
                                                color: Colors.black
                                                    .withOpacity(0.8),
                                                offset: const Offset(0, 4),
                                              ),
                                              Shadow(
                                                blurRadius: 10,
                                                color: Colors.orange.shade900,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Texto "¿Tu media naranja?"
                                        Text(
                                          '¿Tu media naranja?',
                                          style: TextStyle(
                                            fontSize: orangeSize * 0.06,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 1,
                                            shadows: [
                                              Shadow(
                                                blurRadius: 15,
                                                color: Colors.black
                                                    .withOpacity(0.7),
                                                offset: const Offset(0, 2),
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
                      },
                    ),

                    const SizedBox(height: 32),

                    // Texto informativo debajo de la naranja
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Tú y ${widget.matchName} se gustaron',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Toca para continuar',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
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

/// Widget that represents one half of the orange
class _OrangeHalf extends StatelessWidget {
  final String photoUrl;
  final bool isLeftHalf;
  final double size;

  const _OrangeHalf({
    required this.photoUrl,
    required this.isLeftHalf,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, // Ahora es cuadrado para formar un círculo perfecto
      height: size,
      child: ClipPath(
        clipper: CircleHalfClipper(isLeftHalf: isLeftHalf),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // FOTO DE LA PERSONA (hombre / mujer) - RECORTADA EN SEMICÍRCULO
            Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
            ),

            // Overlay de color naranja ligero
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin:
                      isLeftHalf ? Alignment.centerLeft : Alignment.centerRight,
                  end:
                      isLeftHalf ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    Colors.orange.withOpacity(0.25),
                    Colors.deepOrange.withOpacity(0.15),
                  ],
                ),
              ),
            ),

            // Segmentos blancos de la naranja (opcional, puedes comentar si no quieres las líneas)
            CustomPaint(
              painter: _OrangeSegmentPainter(isLeftHalf: isLeftHalf),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter for orange segment lines
class _OrangeSegmentPainter extends CustomPainter {
  final bool isLeftHalf;

  _OrangeSegmentPainter({required this.isLeftHalf});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final center = Offset(
      isLeftHalf ? size.width : 0,
      size.height / 2,
    );

    // Draw radial lines from center to edge
    for (int i = 0; i < 5; i++) {
      final angle = (i / 4) * math.pi - math.pi / 2;
      final endX = center.dx + math.cos(angle) * size.width;
      final endY = center.dy + math.sin(angle) * size.height / 2;

      canvas.drawLine(center, Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(_OrangeSegmentPainter oldDelegate) => false;
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
