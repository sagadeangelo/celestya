import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/discover_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _pages = const [
    DiscoverScreen(),
    MatchesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: CelestyaColors.deepNight,
          boxShadow: [
             BoxShadow(
               color: CelestyaColors.mysticalPurple.withOpacity(0.2),
               blurRadius: 20,
               offset: const Offset(0, -5),
             )
          ]
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          currentIndex: _currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          onTap: (idx) {
            setState(() {
              _currentIndex = idx;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: NeonNavIcon(icon: Icons.explore_outlined, isSelected: false),
              activeIcon: NeonNavIcon(icon: Icons.explore, isSelected: true),
              label: 'Descubrir',
            ),
            BottomNavigationBarItem(
              icon: NeonNavIcon(icon: Icons.favorite_outline, isSelected: false),
              activeIcon: NeonNavIcon(icon: Icons.favorite, isSelected: true),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: NeonNavIcon(icon: Icons.person_outline, isSelected: false),
              activeIcon: NeonNavIcon(icon: Icons.person, isSelected: true),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class NeonNavIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const NeonNavIcon({super.key, required this.icon, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    // Colors based on selection
    final Color solidColor = isSelected ? Colors.white : Colors.white60;
    final Color neonColor = isSelected ? CelestyaColors.celestialBlue : Colors.transparent;
    final double spread = isSelected ? 3.0 : 0.0;
    
    return Container(
      width: 40, 
      height: 40,
      decoration: BoxDecoration(
         // 3D Effect using shadows
         shape: BoxShape.circle,
         color: isSelected ? CelestyaColors.mysticalPurple.withOpacity(0.2) : Colors.transparent, // Gentle background pill
         boxShadow: isSelected ? [
           // Neon Glow Outline
            BoxShadow(
              color: neonColor.withOpacity(0.6),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            // Bottom Right Shadow (3D Depth)
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
              offset: const Offset(3, 3),
            ),
            // Top Left Highlight (3D Light source)
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(-1, -1),
            )
         ] : [],
      ),
      child: Icon(
        icon,
        color: solidColor,
        size: 26,
        // TextShadow for icon (Neon contour on the glyph itself)
        shadows: isSelected ? [
           Shadow(color: neonColor, blurRadius: 12),
        ] : null,
      ),
    );
  }
}
