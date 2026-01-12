// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/text_styles.dart';

/// Paleta principal basada en el logo de Celestya.
class CelestyaColors {
  // === Celestial Palette ===
  
  // Primary (Starlight & Magic)
  static const starlightGold = Color(0xFFFFD700); // Calidez, destino, luz de estrellas
  static const mysticalPurple = Color(0xFF7B2CBF); // Profundidad, misterio, espiritualidad
  static const celestialBlue = Color(0xFF3A86FF); // Confianza, cielo despejado
  
  // Backgrounds (Night Sky System)
  static const spaceBlack = Color(0xFF030308); // El vacío del espacio (fondo principal dark)
  static const deepNight = Color(0xFF0B0E17); // Noche profunda (cards dark)
  static const twilight = Color(0xFF1E1E2C); // Crepúsculo (controles dark)
  
  static const morningMist = Color(0xFFF4F6F8); // Niebla matutina (fondo light)
  static const cloudWhite = Color(0xFFFFFFFF); // Nubes blancas (cards light)

  // Accents (The Glow)
  static const nebulaPink = Color(0xFFFF006E); // Pasión, energía (likes)
  static const auroraTeal = Color(0xFF00B4D8); // Serenidad, calma (info, chats)
  static const starDust = Color(0xFFE0AAFF); // Polvo de estrellas (acentos sutiles)

  // Text
  static const textPrimaryLight = Color(0xFF1A1A2E);
  static const textSecondaryLight = Color(0xFF6E6E80);

  static const textPrimaryDark = Color(0xFFF0F0F5);
  static const textSecondaryDark = Color(0xFFA0A0B0);

  // Gradients
  static const LinearGradient mainGradient = LinearGradient(
    colors: [mysticalPurple, celestialBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warmGradient = LinearGradient(
    colors: [nebulaPink, Color(0xFFFFBE0B)],
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
  );
  
  static const LinearGradient deepSpaceGradient = LinearGradient(
    colors: [spaceBlack, deepNight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Nuevo gradiente más suave para el perfil (Más luz, menos negro)
  static const LinearGradient softSpaceGradient = LinearGradient(
    colors: [Color(0xFF4A3080), Color(0xFF1F1B3E)], // Medium Purple -> Dark Cosmic Purple
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppTheme {
  /// Tema claro
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: CelestyaColors.mysticalPurple,
      brightness: Brightness.light,
      primary: CelestyaColors.mysticalPurple,
      secondary: CelestyaColors.nebulaPink,
      tertiary: CelestyaColors.auroraTeal,
      surface: CelestyaColors.cloudWhite,
      background: CelestyaColors.morningMist,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CelestyaColors.morningMist,
      
      // Tipografía personalizada con Inter
      textTheme: CelestyaTextStyles.createTextTheme(CelestyaColors.textPrimaryLight),
      
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: CelestyaColors.morningMist,
        foregroundColor: CelestyaColors.textPrimaryLight,
        titleTextStyle: CelestyaTextStyles.titleLarge(CelestyaColors.textPrimaryLight),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: DesignTokens.space3,
            horizontal: DesignTokens.space5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          ),
          textStyle: CelestyaTextStyles.labelLarge(colorScheme.onPrimary),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: DesignTokens.space3,
            horizontal: DesignTokens.space5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          ),
          side: BorderSide(color: colorScheme.primary.withOpacity(0.4)),
          textStyle: CelestyaTextStyles.labelLarge(colorScheme.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          vertical: DesignTokens.space3,
          horizontal: DesignTokens.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.15),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.15),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: DesignTokens.elevationMedium,
        margin: EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusXLarge),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 12,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: CelestyaColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  /// Tema oscuro
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: CelestyaColors.mysticalPurple,
      brightness: Brightness.dark,
      primary: CelestyaColors.mysticalPurple, // O starlightGold para más contraste
      secondary: CelestyaColors.nebulaPink,
      tertiary: CelestyaColors.auroraTeal,
      surface: CelestyaColors.deepNight,
      background: CelestyaColors.spaceBlack,
      onSurface: CelestyaColors.textPrimaryDark,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CelestyaColors.spaceBlack,
      
      // Tipografía personalizada con Inter
      textTheme: CelestyaTextStyles.createTextTheme(CelestyaColors.textPrimaryDark),
      
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: CelestyaColors.spaceBlack,
        foregroundColor: CelestyaColors.textPrimaryDark,
        titleTextStyle: CelestyaTextStyles.titleLarge(CelestyaColors.textPrimaryDark),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          side: BorderSide(color: colorScheme.primary.withOpacity(0.5)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF141827),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.7,
          ),
        ),
      ),

      // 👇 Y AQUÍ TAMBIÉN CardThemeData
      cardTheme: const CardThemeData(
        elevation: 14,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF0B0E1B),
        elevation: 16,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: CelestyaColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
