import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/discover_provider.dart';
import '../features/matching/presentation/providers/filter_provider.dart';
import '../features/matching/presentation/widgets/filter_bottom_sheet.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  bool _hasStarted = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Animation for heartbeat
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startDiscovery() {
    setState(() {
      _hasStarted = true;
    });
    // Load candidates only when user starts
    ref.read(discoverProvider.notifier).loadCandidates();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasStarted) {
      return Scaffold(
        backgroundColor: CelestyaColors.deepNight,
        body: _buildIntroView(),
      );
    }

    final state = ref.watch(discoverProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Descubrir'),
        backgroundColor: CelestyaColors.deepNight,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showFilterSheet(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'diagnostics') {
                _showDiagnostics(context, state);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'diagnostics',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Diagnóstico'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CelestyaColors.auroraTeal.withOpacity(0.15),
              Colors.white,
            ],
          ),
        ),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildIntroView() {
    return GestureDetector(
      onTap: _startDiscovery,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CelestyaColors.deepNight,
                  Color(0xFF2D1E4E), // Slightly lighter purple
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CelestyaColors.nebulaPink.withOpacity(0.2),
                          boxShadow: [
                            BoxShadow(
                              color: CelestyaColors.nebulaPink.withOpacity(0.4),
                              blurRadius: 40,
                              spreadRadius: 10,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 80,
                          color: CelestyaColors.nebulaPink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Encuentra tu conexión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Toca para comenzar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DiscoverState state) {
    if (state.isLoading && state.candidates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // ... rest of _buildBody logic ...
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${state.error}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(discoverProvider.notifier).loadCandidates(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (state.candidates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off,
                size: 80, color: CelestyaColors.nebulaPink),
            const SizedBox(height: 16),
            const Text(
              'No hay candidatos con tus filtros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            // Suggest broader filters
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Intenta ampliar la edad o distancia para ver a los testers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ref
                        .read(filterProvider.notifier)
                        .resetFilters(); // Correct method name
                    ref
                        .read(discoverProvider.notifier)
                        .loadCandidates(forceRefresh: true);
                  },
                  child: const Text('Restablecer'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _showFilterSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestyaColors.nebulaPink,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ajustar Filtros'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final candidate = state.candidates.first;
    return _buildCandidateCard(candidate);
  }

  Widget _buildCandidateCard(candidate) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Maximize photo height, leaving just enough space for buttons (approx 100px + padding)
        final cardHeight = availableHeight - 140;
        final cardWidth = availableWidth * 0.95; // Wider card

        return Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Swipeable Photo Card
                SizedBox(
                  height: cardHeight,
                  width: cardWidth,
                  child: Dismissible(
                    key: Key(candidate.id),
                    direction: DismissDirection.horizontal,
                    onDismissed: (direction) {
                      if (direction == DismissDirection.endToStart) {
                        // Swipe Left -> Pass
                        ref
                            .read(discoverProvider.notifier)
                            .passCandidate(candidate.id);
                      } else {
                        // Swipe Right -> Like
                        ref
                            .read(discoverProvider.notifier)
                            .likeCandidate(candidate.id)
                            .then((matched) {
                          if (matched && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Es un match! 💕'),
                                backgroundColor: CelestyaColors.nebulaPink,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        });
                      }
                    },
                    background: Container(
                      decoration: BoxDecoration(
                        color: CelestyaColors.nebulaPink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 30),
                      child: const Icon(Icons.favorite,
                          color: Colors.white, size: 50),
                    ),
                    secondaryBackground: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 30),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 50),
                    ),
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                CelestyaColors.mysticalPurple.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Photo
                            candidate.photoUrl != null
                                ? Image.network(
                                    candidate.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildPlaceholder(),
                                  )
                                : _buildPlaceholder(),

                            // Compatibility Bar Overlay (Top)
                            Positioned(
                              top: 16,
                              left: 16,
                              right: 16,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: candidate.compatibility ??
                                            0.5, // Default 50% if null
                                        backgroundColor: Colors.black26,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                          CelestyaColors.nebulaPink,
                                        ),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${((candidate.compatibility ?? 0.5) * 100).toInt()}% Match',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Gradient overlay (Bottom Info)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.9),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.8],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${candidate.name}${candidate.age != null ? ", ${candidate.age}" : ""}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (candidate.city.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          candidate.city,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 18,
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
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pass Button
                    _buildActionButton(
                      icon: Icons.close,
                      color: Colors.red,
                      onPressed: () async {
                        await ref
                            .read(discoverProvider.notifier)
                            .passCandidate(candidate.id);
                      },
                    ),

                    const SizedBox(width: 40),

                    // Like Button
                    _buildActionButton(
                      icon: Icons.favorite,
                      color: CelestyaColors.nebulaPink,
                      onPressed: () async {
                        final matched = await ref
                            .read(discoverProvider.notifier)
                            .likeCandidate(candidate.id);
                        if (matched && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Es un match! 💕'),
                              backgroundColor: CelestyaColors.nebulaPink,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: CelestyaColors.deepNight.withOpacity(0.1),
      child: const Center(
        child: Icon(Icons.person, size: 100, color: Colors.grey),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, size: 35, color: color),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const FilterBottomSheet(),
    );
  }

  void _showDiagnostics(BuildContext context, DiscoverState state) {
    // Get user profile for diagnostics (if available)
    // For now, just show basic info
    final filters = ref.read(filterProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 Diagnóstico de Filtros'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Estado actual:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• Candidatos recibidos: ${state.candidates.length}'),
              Text('• Cargando: ${state.isLoading}'),
              if (state.error != null) ...[
                const SizedBox(height: 8),
                const Text('Error:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red)),
                Text(state.error!, style: const TextStyle(color: Colors.red)),
              ],
              const Divider(height: 24),
              const Text('Filtros activos (Provider):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• max_distance_km: ${filters.maxDistance} km'),
              Text(
                  '• age_range: ${filters.ageRange.start.round()} - ${filters.ageRange.end.round()}'),
              const Divider(height: 24),
              const Text('Nota:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Estos valores se envían como query params al backend /matches/suggested.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (state.backendDebugInfo != null) ...[
                const Divider(height: 24),
                const Text('Backend Debug Info:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    '• Filtros recibidos: ${state.backendDebugInfo!['requested_filters']}'),
                Text(
                    '• Total usuarios: ${state.backendDebugInfo!['total_users']}'),
                Text(
                    '• Despues exclusiones: ${state.backendDebugInfo!['after_exclusions']}'),
                Text(
                    '• Conteo final: ${state.backendDebugInfo!['final_count']}'),
                Text('• Toggles: ${state.backendDebugInfo!['toggles']}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
