// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';
import '../core/theme/text_styles.dart';

/// Paleta principal basada en el logo de Celestya.
class CelestyaColors {
  // Degradado: rosa → violeta → azul
  static const pink = Color(0xFFFF6BA6);
  static const purple = Color(0xFF9B5CFF);
  static const blue = Color(0xFF246BFF);

  static const backgroundLight = Color(0xFFFDF7FF);
  static const backgroundDark = Color(0xFF050817);

  static const textPrimaryLight = Color(0xFF1E1B2A);
  static const textSecondaryLight = Color(0xFF756B8A);

  static const textPrimaryDark = Color(0xFFF5F0FF);
  static const textSecondaryDark = Color(0xFFB2A9D5);
}

class AppTheme {
  /// Tema claro
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: CelestyaColors.purple,
      brightness: Brightness.light,
      primary: CelestyaColors.purple,
      secondary: CelestyaColors.pink,
      surface: Colors.white,
      background: CelestyaColors.backgroundLight,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CelestyaColors.backgroundLight,
      
      // Tipografía personalizada con Inter
      textTheme: CelestyaTextStyles.createTextTheme(CelestyaColors.textPrimaryLight),
      
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: CelestyaColors.backgroundLight,
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
      seedColor: CelestyaColors.purple,
      brightness: Brightness.dark,
      primary: CelestyaColors.purple,
      secondary: CelestyaColors.pink,
      surface: const Color(0xFF0F1220),
      background: CelestyaColors.backgroundDark,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: CelestyaColors.backgroundDark,
      
      // Tipografía personalizada con Inter
      textTheme: CelestyaTextStyles.createTextTheme(CelestyaColors.textPrimaryDark),
      
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: CelestyaColors.backgroundDark,
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
