import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/discover_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_review_screen.dart'; // New
import 'features/chats/chats_provider.dart';

import 'widgets/profile_gate.dart';
import 'providers/navigation_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _pages = const [
    ProfileGate(child: DiscoverScreen()),
    ProfileGate(child: MatchesScreen()),
    InboxScreen(),
    ProfileScreen(),
  ];

  int _adminTaps = 0;
  DateTime? _lastTap;

  @override
  Widget build(BuildContext context) {
    // Watch chats to get unread count
    final chatsAsync = ref.watch(chatsListProvider);
    final unreadCount = chatsAsync.maybeWhen(
      data: (chats) =>
          chats.fold<int>(0, (sum, chat) => sum + chat.unreadCount),
      orElse: () => 0,
    );

    // Watch navigation index
    final currentIndex = ref.watch(navIndexProvider);

    return Scaffold(
      body: _pages[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: CelestyaColors.deepNight, boxShadow: [
          BoxShadow(
            color: CelestyaColors.mysticalPurple.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ]),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: currentIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white54,
          type: BottomNavigationBarType.fixed,
          onTap: _handleAdminTap,
          items: [
            const BottomNavigationBarItem(
              icon:
                  NeonNavIcon(icon: Icons.explore_outlined, isSelected: false),
              activeIcon: NeonNavIcon(icon: Icons.explore, isSelected: true),
              label: 'Descubrir',
            ),
            const BottomNavigationBarItem(
              icon:
                  NeonNavIcon(icon: Icons.favorite_outline, isSelected: false),
              activeIcon: NeonNavIcon(icon: Icons.favorite, isSelected: true),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: _BadgeIcon(
                  icon: Icons.chat_bubble_outline,
                  count: unreadCount,
                  isSelected: false),
              activeIcon: _BadgeIcon(
                  icon: Icons.chat_bubble,
                  count: unreadCount,
                  isSelected: true),
              label: 'Chats',
            ),
            const BottomNavigationBarItem(
              icon: NeonNavIcon(icon: Icons.person_outline, isSelected: false),
              activeIcon: NeonNavIcon(icon: Icons.person, isSelected: true),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  void _handleAdminTap(int idx) {
    if (idx == 3) {
      final now = DateTime.now();
      if (_lastTap == null ||
          now.difference(_lastTap!) > const Duration(seconds: 2)) {
        _adminTaps = 1;
      } else {
        _adminTaps++;
      }
      _lastTap = now;

      if (_adminTaps >= 5) {
        _adminTaps = 0;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminReviewScreen()),
        );
      }
    } else {
      _adminTaps = 0;
    }

    ref.read(navIndexProvider.notifier).state = idx;
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isSelected;

  const _BadgeIcon(
      {required this.icon, required this.count, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NeonNavIcon(icon: icon, isSelected: isSelected),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF00FF94), // Neon Green
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
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
    final Color neonColor =
        isSelected ? CelestyaColors.celestialBlue : Colors.transparent;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        // 3D Effect using shadows
        shape: BoxShape.circle,
        color: isSelected
            ? CelestyaColors.mysticalPurple.withOpacity(0.2)
            : Colors.transparent, // Gentle background pill
        boxShadow: isSelected
            ? [
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
              ]
            : [],
      ),
      child: Icon(
        icon,
        color: solidColor,
        size: 26,
        // TextShadow for icon (Neon contour on the glyph itself)
        shadows: isSelected
            ? [
                Shadow(color: neonColor, blurRadius: 12),
              ]
            : null,
      ),
    );
  }
}
