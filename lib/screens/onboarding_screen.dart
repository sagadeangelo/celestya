import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLastPage = false;

  final List<_OnboardingSlide> _slides = [
    const _OnboardingSlide(
      title: "Conexiones con propósito",
      subtitle: "personas que buscan algo real, no ruido.",
      icon: Icons.auto_awesome_outlined, // Constelaciones
      isLogo: false,
    ),
    const _OnboardingSlide(
      title: "Valores antes que apariencias",
      subtitle: "Fe, respeto y visión de vida compartida.",
      icon: Icons.favorite_border, // Luz cálida / conversación
      isLogo: false,
    ),
    const _OnboardingSlide(
      title: "La persona que resuena contigo",
      subtitle: "Celestya no empareja. Guía.",
      icon: Icons.favorite, // Logo placeholder (será reemplazado por asset real si existe)
      isLogo: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/auth_gate');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (Fijo para dar continuidad)
          Container(
            decoration: const BoxDecoration(
              gradient: CelestyaColors.mainGradient,
            ),
          ),
          
          // Pattern Overlay (opcional, para dar textura)
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.asset(
                'assets/app_icon.png', // Usamos el icono como patrón sutil repetido si fuera posible, o un color sólido
                repeat: ImageRepeat.repeat,
                errorBuilder: (_,__,___) => const SizedBox(),
              ),
            ),
          ),

          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _isLastPage = index == _slides.length - 1;
              });
            },
            itemBuilder: (context, index) {
              return _BuildSlide(data: _slides[index]);
            },
          ),

          // Indicators & Controls
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Page Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index 
                            ? CelestyaColors.starlightGold 
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLastPage 
                        ? _finishOnboarding 
                        : () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 600), 
                              curve: Curves.easeInOutCubicEmphasized,
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: CelestyaColors.starlightGold,
                      foregroundColor: CelestyaColors.deepNight,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                      shadowColor: CelestyaColors.starlightGold.withOpacity(0.5),
                    ),
                    child: Text(
                      _isLastPage ? "Comenzar mi viaje" : "Continuar",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLogo;

  const _OnboardingSlide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLogo,
  });
}

class _BuildSlide extends StatelessWidget {
  final _OnboardingSlide data;

  const _BuildSlide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Visual Element
          Expanded(
            flex: 5,
            child: Center(
              child: _buildVisual(context),
            ),
          ),
          
          // Text Content
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  data.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisual(BuildContext context) {
    if (data.isLogo) {
      // Screen 3: Breathing Logo
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.9, end: 1.1),
        duration: const Duration(seconds: 4), // Slower breathing
        curve: Curves.easeInOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: CelestyaColors.starlightGold.withOpacity(0.3),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                  BoxShadow(
                    color: CelestyaColors.nebulaPink.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/app_icon.png',
                width: 180,
                height: 180,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.favorite,
                  size: 150,
                  color: CelestyaColors.nebulaPink,
                ),
              ),
            ),
          );
        },
        onEnd: () {/* Loop logic would go here if needed */}, 
      );
    }

    if (data.title.contains("Conexiones")) {
      // Screen 1: Constellations
      return const _ConstellationVisual();
    }

    if (data.title.contains("Valores")) {
      // Screen 2: Warm Light
      return const _WarmLightVisual();
    }

    // Fallback
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Icon(
        data.icon,
        size: 80,
        color: Colors.white.withOpacity(0.9),
      ),
    );
  }
}

class _ConstellationVisual extends StatefulWidget {
  const _ConstellationVisual();

  @override
  State<_ConstellationVisual> createState() => _ConstellationVisualState();
}

class _ConstellationVisualState extends State<_ConstellationVisual> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 10),
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
        return CustomPaint(
          size: const Size(200, 200),
          painter: _ConstellationPainter(animationValue: _controller.value),
        );
      },
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  final double animationValue;
  _ConstellationPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Define star points (simulating a constellation)
    final points = [
      Offset(size.width * 0.2, size.height * 0.4),
      Offset(size.width * 0.4, size.height * 0.2),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.7),
      Offset(size.width * 0.3, size.height * 0.8),
    ];

    // Breahing movement using animationValue
    final move = 5.0 * animationValue;

    final animatedPoints = points.map((p) {
      return Offset(p.dx, p.dy - move);
    }).toList();

    // Draw lines
    final path = Path();
    path.moveTo(animatedPoints[0].dx, animatedPoints[0].dy);
    path.lineTo(animatedPoints[1].dx, animatedPoints[1].dy);
    path.lineTo(animatedPoints[2].dx, animatedPoints[2].dy);
    path.lineTo(animatedPoints[3].dx, animatedPoints[3].dy);
    path.lineTo(animatedPoints[4].dx, animatedPoints[4].dy);
    path.lineTo(animatedPoints[5].dx, animatedPoints[5].dy);
    path.close();

    canvas.drawPath(path, paint);

    // Draw stars (dots) with glow
    for (var point in animatedPoints) {
      canvas.drawCircle(point, 3, dotPaint);
      canvas.drawCircle(
        point, 
        8 + (4 * animationValue), 
        Paint()..color = Colors.white.withOpacity(0.15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) => true;
}

class _WarmLightVisual extends StatelessWidget {
  const _WarmLightVisual();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFFFBE0B).withOpacity(0.6), // Warm Gold
            const Color(0xFFFF006E).withOpacity(0.1), // Nebula Pink hint
            Colors.transparent,
          ],
          stops: const [0.2, 0.6, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite, size: 40, color: Colors.white.withOpacity(0.9)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, size: 30, color: Colors.white.withOpacity(0.7)),
                const SizedBox(width: 8),
                Icon(Icons.person_outline, size: 30, color: Colors.white.withOpacity(0.7)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
