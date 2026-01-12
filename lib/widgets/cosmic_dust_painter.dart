import 'dart:math';
import 'package:flutter/material.dart';

class CosmicDustPainter extends CustomPainter {
  final Color color;
  final int numberOfParticles;

  CosmicDustPainter({
    this.color = const Color(0xFFE0E0E0), // Plated Silver
    this.numberOfParticles = 400,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    
    // 1. Nebula Cloud (Centered behind Avatar area)
    // Larger radius to cover more background
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFE0E0E0).withOpacity(0.15), 
          const Color(0xFF8A2BE2).withOpacity(0.1), 
          Colors.transparent
        ],
        stops: const [0.0, 0.4, 0.9],
        center: Alignment.topCenter,
        radius: 1.1, 
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), nebulaPaint);

    // 2. Stars (Background)
    final starPaint = Paint()
      ..color = Colors.white.withOpacity(0.8) // Brighter
      ..style = PaintingStyle.fill;

    // Glowing Star Paint (for effects)
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    for (int i = 0; i < numberOfParticles; i++) {
        double dx = random.nextDouble() * size.width;
        double dy = size.height * pow(random.nextDouble(), 0.7); // Spread vertically
        
        // Size variation: mainly small stars, some medium
        double baseSize = random.nextDouble() * 1.5 + 0.5; 
        
        if (random.nextDouble() > 0.95) {
           // 3. Bright "Hero" Stars (5% of particles)
           double bigStarSize = random.nextDouble() * 2.5 + 2.0;
           
           // Draw glow
           canvas.drawCircle(Offset(dx, dy), bigStarSize + 4, glowPaint);
           
           // Draw bright core
           canvas.drawCircle(Offset(dx, dy), bigStarSize, Paint()..color = Colors.white);

           // Visual Flare (Cross effect) for nice aesthetic
           if (random.nextDouble() > 0.7) {
             _drawFlare(canvas, Offset(dx, dy), bigStarSize * 3, Colors.white.withOpacity(0.6));
           }

        } else {
           // Normal Stars/Dust
           starPaint.color = color.withOpacity(random.nextDouble() * 0.7 + 0.3);
           canvas.drawCircle(Offset(dx, dy), baseSize, starPaint);
        }
    }
  }

  void _drawFlare(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - size, center.dy),
      Offset(center.dx + size, center.dy),
      paint,
    );
    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - size),
      Offset(center.dx, center.dy + size),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
