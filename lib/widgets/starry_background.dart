import 'dart:math';
import 'package:flutter/material.dart';

class StarryBackground extends StatefulWidget {
  final int numberOfStars;
  final Color baseColor;

  const StarryBackground({
    super.key,
    this.numberOfStars = 200, 
    this.baseColor = const Color(0xFFE0E0E0),
  });

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = [];
  final Random _random = Random();
  
  // Shooting Star State
  _ShootingStar? _activeShootingStar;
  double _shootingStarProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // Slightly faster twinkle cycle
    )..repeat();

    _controller.addListener(_tick);

    _generateStars();
  }

  void _generateStars() {
    _stars.clear();
    // Star Colors (REALISM: Blue-hot, White, Yellow-cool)
    final starColors = [
      const Color(0xFFFFFFFF), // Pure White
      const Color(0xFFD8E6FF), // Blue White (Sirius-like)
      const Color(0xFFFFFAD8), // Yellow White (Capella-like)
      const Color(0xFFC8E0FF), // Bright Blue
    ];

    for (int i = 0; i < widget.numberOfStars; i++) {
      _stars.add(_Star(
        x: _random.nextDouble(),
        y: pow(_random.nextDouble(), 0.8).toDouble(),
        // Varied sizes, slightly larger on average for visibility
        size: _random.nextDouble() * 2.2 + 0.6,
        twinkleOffset: _random.nextDouble() * 2 * pi,
        brightness: _random.nextDouble(),
        color: starColors[_random.nextInt(starColors.length)],
      ));
    }
  }

  void _tick() {
    // Probabilistic spawn: 0.5% chance per frame
    if (_activeShootingStar == null && _random.nextDouble() < 0.005) {
       _spawnShootingStar();
    }

    if (_activeShootingStar != null) {
      setState(() {
        _shootingStarProgress += 0.02; 
        if (_shootingStarProgress >= 1.0) {
          _activeShootingStar = null;
          _shootingStarProgress = 0.0;
        }
      });
    } else {
        setState(() {}); 
    }
  }

  void _spawnShootingStar() {
     double startX, startY, endX, endY;
     
     if (_random.nextBool()) {
       startX = _random.nextDouble();
       startY = -0.1;
     } else {
       startX = -0.1;
       startY = _random.nextDouble() * 0.5;
     }

     endX = startX + 0.5 + _random.nextDouble() * 0.5;
     endY = startY + 0.5 + _random.nextDouble() * 0.5;
     
     _activeShootingStar = _ShootingStar(
       from: Offset(startX, startY),
       to: Offset(endX, endY),
     );
     _shootingStarProgress = 0.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarryPainter(
        stars: _stars,
        animationValue: _controller.value,
        baseColor: widget.baseColor,
        shootingStar: _activeShootingStar,
        shootingStarProgress: _shootingStarProgress,
      ),
      isComplex: true,
      willChange: true,
    );
  }
}

class _Star {
  final double x; 
  final double y; 
  final double size;
  final double twinkleOffset;
  final double brightness;
  final Color color;

  _Star({
    required this.x, 
    required this.y, 
    required this.size, 
    required this.twinkleOffset, 
    required this.brightness,
    required this.color,
  });
}

class _ShootingStar {
  final Offset from;
  final Offset to;
  _ShootingStar({required this.from, required this.to});
}

class _StarryPainter extends CustomPainter {
  final List<_Star> stars;
  final double animationValue;
  final Color baseColor;
  final _ShootingStar? shootingStar;
  final double shootingStarProgress;

  _StarryPainter({
    required this.stars,
    required this.animationValue,
    required this.baseColor,
    this.shootingStar,
    this.shootingStarProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Nebula Clouds (Slightly brighter/more visible base)
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
           baseColor.withOpacity(0.12),
           const Color(0xFF8A2BE2).withOpacity(0.06),
           Colors.transparent
        ],
        stops: const [0.0, 0.5, 1.0],
        center: Alignment.topCenter,
        radius: 1.3,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), nebulaPaint);

    // 2. Stars
    final starPaint = Paint()..style = PaintingStyle.fill;
    
    // Pre-calculated glow paint to avoid object creation in loop
    final glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    for (final star in stars) {
       double t = DateTime.now().millisecondsSinceEpoch / 1000.0;
       double twinkle = sin(t * 3 + star.twinkleOffset) * 0.5 + 0.5; // Faster twinkle
       
       // BRIGHTNESS BOOST: Min opacity 0.5 instead of 0.3
       double opacity = 0.5 + (twinkle * 0.5); 
       
       // Factor in intrinsic star brightness
       opacity *= (0.6 + star.brightness * 0.4);

       Color renderColor = star.color.withOpacity(opacity.clamp(0.0, 1.0));
       
       final pos = Offset(star.x * size.width, star.y * size.height);
       
       // Draw Glow (Bloom) for more stars (size > 1.2 instead of 2.0)
       // This simulates atmospheric scattering / camera bloom on bright point sources
       if (star.size > 1.2) {
         glowPaint.color = star.color.withOpacity(0.3 * opacity); // Tinted glow
         canvas.drawCircle(pos, star.size + 1.5, glowPaint);
       }
       
       // Draw Core
       starPaint.color = renderColor;
       canvas.drawCircle(pos, star.size, starPaint);
       
       // Draw "White Hot" center for very large stars
       if (star.size > 2.0) {
         canvas.drawCircle(pos, star.size * 0.5, Paint()..color = Colors.white.withOpacity(0.9));
       }
    }

    // 3. Shooting Star
    if (shootingStar != null) {
       final p1 = shootingStar!.from;
       final p2 = shootingStar!.to;
       
       final currentPos = Offset.lerp(
         Offset(p1.dx * size.width, p1.dy * size.height),
         Offset(p2.dx * size.width, p2.dy * size.height),
         shootingStarProgress
       )!;

       final tailLen = 0.2; // Longer tail
       final tailStartProgress = (shootingStarProgress - tailLen).clamp(0.0, 1.0);
       final tailPos = Offset.lerp(
         Offset(p1.dx * size.width, p1.dy * size.height),
         Offset(p2.dx * size.width, p2.dy * size.height),
         tailStartProgress
       )!;
       
       final shootingPaint = Paint()
         ..shader = LinearGradient(
           colors: [Colors.transparent, Colors.white],
           stops: const [0.0, 1.0],
         ).createShader(Rect.fromPoints(tailPos, currentPos))
         ..strokeWidth = 2.5
         ..strokeCap = StrokeCap.round;
         
       canvas.drawLine(tailPos, currentPos, shootingPaint);
       
       // Head glow
       canvas.drawCircle(currentPos, 4.0, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
       canvas.drawCircle(currentPos, 2.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _StarryPainter oldDelegate) {
    return true; 
  }
}
