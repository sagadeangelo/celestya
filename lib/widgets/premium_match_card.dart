// lib/widgets/premium_match_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../data/match_candidate.dart';
import '../screens/match_detail_screen.dart';

class PremiumMatchCard extends StatefulWidget {
  final MatchCandidate candidate;
  final bool isPreview; // Habilita navegación de fotos si son múltiples

  const PremiumMatchCard({
    super.key, 
    required this.candidate,
    this.isPreview = false,
  });

  @override
  State<PremiumMatchCard> createState() => _PremiumMatchCardState();
}

class _PremiumMatchCardState extends State<PremiumMatchCard> {
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();
  
  List<String> get _photos {
    final photos = <String>[];
    if (widget.candidate.photoUrl != null && widget.candidate.photoUrl!.isNotEmpty) {
      photos.add(widget.candidate.photoUrl!);
    }
    photos.addAll(widget.candidate.photoUrls);
    return photos;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = widget.candidate;
    final photos = _photos;
    final hasMultiplePhotos = photos.length > 1;

    ImageProvider? getImageProvider(String path) {
      if (path.startsWith('http')) {
        return NetworkImage(path);
      } else if (path.isNotEmpty) {
        return FileImage(File(path));
      }
      return null;
    }

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
            // 1. Carrusel de Fotos (PageView para swipe)
            if (photos.isNotEmpty)
              // Solo habilitamos swipe si es preview o si queremos que siempre se pueda ver más fotos
              // El usuario pidió "mover pantalla hacia la izquierda", es decir, swipe nativo.
              // Si NO es preview (es match screen), AppinioSwiper maneja el swipe de la carta.
              // Esto puede crear conflicto de gestos.
              // PERO: Tinder permite tap para cambiar foto. PageView captura drag.
              // En Match Screen: PageController puede interferir con Swiper si es horizontal.
              // Solución para Match Screen: Deshabilitar swipe del PageView (physics: NeverScrollable)
              // y usar Taps.
              // Solución para Preview: Habilitar swipe.
              PageView.builder(
                controller: _pageController,
                physics: widget.isPreview 
                    ? const BouncingScrollPhysics() 
                    : const NeverScrollableScrollPhysics(), // En match screen, solo tap
                onPageChanged: (index) {
                  setState(() => _currentPhotoIndex = index);
                },
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final imgProvider = getImageProvider(photos[index]);
                  if (imgProvider == null) return const SizedBox();
                  
                  // Envolver en GestureDetector si no es Preview para permitir cambio por Taps
                  // Si ES preview, PageView ya maneja el swipe.
                  return GestureDetector(
                    onTapUp: (details) {
                      final width = MediaQuery.of(context).size.width;
                      final dx = details.localPosition.dx;
                      
                      // Zonas de Tap:
                      // 0% - 25%: Foto Anterior
                      // 75% - 100%: Siguiente Foto
                      // 25% - 75%: Ver Detalles (Centro)
                      
                      if (dx < width * 0.25) {
                         // Izquierda: Foto anterior
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 250), 
                          curve: Curves.easeInOut
                        );
                      } else if (dx > width * 0.75) {
                        // Derecha: Siguiente foto
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut
                        );
                      } else {
                        // Centro: Ver Perfil Completo
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MatchDetailScreen(candidate: candidate),
                          ),
                        );
                      }
                    },
                    child: Hero(
                       tag: 'match_photo_${candidate.id}', // Hero tag linking to detail screen
                       child: Image(
                        image: imgProvider,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(Icons.person, size: 80, color: theme.colorScheme.primary),
                ),
              ),
            
            // 2. Foto Indicators (keeping these at top)
            if (hasMultiplePhotos)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: List.generate(photos.length, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index == _currentPhotoIndex 
                              ? Colors.white 
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // 3. Gradiente Oscuro inferior
            Positioned.fill(
              child: IgnorePointer( // Importante: Ignorar toques para que pasen al PageView
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
            ),
            
            // 3. Info del usuario con protección de Overflow
            Positioned(
              left: 20,
              right: 20,
              bottom: 30,
              child: IgnorePointer( // Permitir swipe sobre el texto
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Usar Flexible para evitar overflow si el nombre es muy largo
                        Flexible(
                          child: Text(
                            candidate.name,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (candidate.age != null)
                          Text(
                            '${candidate.age}',
                             style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Ubicación
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            candidate.city,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Altura
                    if (candidate.height > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.height, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                             Text(
                              '${candidate.height.round()} cm',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Chips de Intereses
                    if (candidate.interests.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 4,
                          children: candidate.interests.take(3).map((i) => 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                i, 
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            )
                          ).toList(),
                        ),
                      ),

                    if (candidate.bio != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        candidate.bio!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Compatibility Bar (Bottom Relocated)
                    if (candidate.compatibility > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 20), // Reduced from 42 to avoid overflow
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'COMPATIBILIDAD',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: candidate.compatibility),
                                  duration: const Duration(milliseconds: 1500),
                                  curve: Curves.easeOutQuart,
                                  builder: (context, value, _) {
                                    final percent = (value * 100).toInt();
                                    final Color barColor = value < 0.5
                                        ? Color.lerp(Colors.red, Colors.yellow, value * 2) ?? Colors.orange
                                        : Color.lerp(Colors.yellow, Colors.greenAccent, (value - 0.5) * 2) ?? Colors.green;
                                    
                                    return Text(
                                      '$percent%',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: barColor,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10), // Increased from 6
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: candidate.compatibility),
                                  duration: const Duration(milliseconds: 1500),
                                  curve: Curves.easeOutQuart,
                                  builder: (context, value, _) {
                                    final Color barColor = value < 0.5
                                        ? Color.lerp(Colors.red, Colors.yellow, value * 2) ?? Colors.orange
                                        : Color.lerp(Colors.yellow, Colors.greenAccent, (value - 0.5) * 2) ?? Colors.green;
                                    
                                    return Stack(
                                      children: [
                                        // Background track
                                        Container(
                                          height: 14, // Adjusted to 14px
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        // Glowing Bar
                                        Container(
                                          height: 14, // Adjusted to 14px
                                          width: constraints.maxWidth * value,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            gradient: LinearGradient(
                                              colors: [
                                                barColor.withOpacity(0.7),
                                                barColor,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: barColor.withOpacity(0.5),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
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
