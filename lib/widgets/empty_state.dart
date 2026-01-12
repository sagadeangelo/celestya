import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget reutilizable para mostrar estados vacíos de forma atractiva y celestial
class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Breathing, very slow
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
     _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Celestial Animated Icon
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: CelestyaColors.mainGradient, // Deep mystic gradient
                      boxShadow: [
                        BoxShadow(
                          color: CelestyaColors.starlightGold.withOpacity(0.2 * _fadeAnimation.value),
                          blurRadius: 30,
                          spreadRadius: 5 * _fadeAnimation.value,
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 64,
                      color: CelestyaColors.starlightGold.withOpacity(0.9),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            
            // Título
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Mensaje
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.white.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            
            // Botón de acción opcional
            if (widget.actionLabel != null && widget.onAction != null) ...[
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: widget.onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: CelestyaColors.starlightGold,
                  side: BorderSide(color: CelestyaColors.starlightGold.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(widget.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
