// lib/widgets/premium_match_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../data/match_candidate.dart';
import '../screens/match_detail_screen.dart';
import '../services/api_client.dart';

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
    if (widget.candidate.photoUrl != null &&
        widget.candidate.photoUrl!.isNotEmpty) {
      photos.add(widget.candidate.photoUrl!);
    }
    // Si ya tenemos photoUrl, esa es la versión firmada de la photoKey principal.
    // Solo agregar photoKey si photoUrl está vacía y queremos que _RemoteImage la resuelva.
    if (widget.candidate.photoKey != null &&
        (widget.candidate.photoUrl == null ||
            widget.candidate.photoUrl!.isEmpty)) {
      photos.add(widget.candidate.photoKey!);
    }
    photos.addAll(widget.candidate.photoUrls);
    return photos
        .toSet()
        .where((p) => p.isNotEmpty)
        .toList(); // Evitar duplicados y vacíos
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageProvider? _getImageProvider(String path) {
    if (path.startsWith('http')) {
      return NetworkImage(path);
    } else if (path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidate = widget.candidate;
    final photos = _photos;
    final hasMultiplePhotos = photos.length > 1;

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
            if (photos.isNotEmpty)
              PageView.builder(
                controller: _pageController,
                physics: widget.isPreview
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPhotoIndex = index);
                },
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final bool isR2Key = !photo.startsWith('http') &&
                      !photo.startsWith('/') &&
                      !photo.contains(':\\');

                  return GestureDetector(
                    onTapUp: (details) {
                      final width = MediaQuery.of(context).size.width;
                      final dx = details.localPosition.dx;

                      if (dx < width * 0.25) {
                        _pageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut);
                      } else if (dx > width * 0.75) {
                        _pageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                MatchDetailScreen(candidate: candidate),
                          ),
                        );
                      }
                    },
                    child: Hero(
                      tag: 'match_photo_${candidate.id}_$index',
                      child: isR2Key
                          ? _RemoteImage(photoKey: photo)
                          : Image(
                              image: _getImageProvider(photo) ??
                                  const AssetImage('assets/placeholder.png')
                                      as ImageProvider,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(color: Colors.grey.shade300),
                            ),
                    ),
                  );
                },
              )
            else
              Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(Icons.person,
                      size: 80, color: theme.colorScheme.primary),
                ),
              ),

            // Indicators, Gradients, and Info (Rest of UI)
            _buildUIOverlay(
                context, theme, candidate, photos, hasMultiplePhotos),
          ],
        ),
      ),
    );
  }

  Widget _buildUIOverlay(BuildContext context, ThemeData theme,
      MatchCandidate candidate, List<String> photos, bool hasMultiplePhotos) {
    return Stack(
      children: [
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
        Positioned.fill(
          child: IgnorePointer(
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
        Positioned(
          left: 20,
          right: 20,
          bottom: 30,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
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
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: Colors.white70, size: 16),
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
                if (candidate.interests.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 4,
                      children: candidate.interests
                          .take(3)
                          .map((i) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  i,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RemoteImage extends StatefulWidget {
  final String photoKey;
  const _RemoteImage({required this.photoKey});

  @override
  State<_RemoteImage> createState() => _RemoteImageState();
}

class _RemoteImageState extends State<_RemoteImage> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiClient.getJson('/media/url?key=${widget.photoKey}');
      if (mounted)
        setState(() {
          _url = res['url'];
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    if (_url == null)
      return Container(
          color: Colors.grey.shade300, child: const Icon(Icons.error));
    return Image.network(
      '$_url&t=${DateTime.now().millisecondsSinceEpoch}',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
    );
  }
}
