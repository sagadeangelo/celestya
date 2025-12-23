// lib/core/theme/text_styles.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de tipografía para Celestya
/// Basado en Material Design 3 con fuente Inter
class CelestyaTextStyles {
  // Fuente base
  static String get _fontFamily => GoogleFonts.inter().fontFamily!;

  // ============================================
  // DISPLAY STYLES (Títulos muy grandes)
  // ============================================
  static TextStyle displayLarge(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w700,
        height: 1.12,
        letterSpacing: -0.25,
        color: color,
      );

  static TextStyle displayMedium(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 45,
        fontWeight: FontWeight.w700,
        height: 1.16,
        color: color,
      );

  static TextStyle displaySmall(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.22,
        color: color,
      );

  // ============================================
  // HEADLINE STYLES (Títulos de sección)
  // ============================================
  static TextStyle headlineLarge(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: color,
      );

  static TextStyle headlineMedium(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.29,
        color: color,
      );

  static TextStyle headlineSmall(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.33,
        color: color,
      );

  // ============================================
  // TITLE STYLES (Títulos de cards, diálogos)
  // ============================================
  static TextStyle titleLarge(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.27,
        color: color,
      );

  static TextStyle titleMedium(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.5,
        letterSpacing: 0.15,
        color: color,
      );

  static TextStyle titleSmall(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
        color: color,
      );

  // ============================================
  // BODY STYLES (Texto principal)
  // ============================================
  static TextStyle bodyLarge(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle bodyMedium(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        letterSpacing: 0.25,
        color: color,
      );

  static TextStyle bodySmall(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        letterSpacing: 0.4,
        color: color,
      );

  // ============================================
  // LABEL STYLES (Botones, tabs, chips)
  // ============================================
  static TextStyle labelLarge(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.43,
        letterSpacing: 0.1,
        color: color,
      );

  static TextStyle labelMedium(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.33,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle labelSmall(Color color) => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.5,
        color: color,
      );

  // ============================================
  // HELPER: Crear TextTheme completo
  // ============================================
  static TextTheme createTextTheme(Color primaryColor) {
    return TextTheme(
      displayLarge: displayLarge(primaryColor),
      displayMedium: displayMedium(primaryColor),
      displaySmall: displaySmall(primaryColor),
      headlineLarge: headlineLarge(primaryColor),
      headlineMedium: headlineMedium(primaryColor),
      headlineSmall: headlineSmall(primaryColor),
      titleLarge: titleLarge(primaryColor),
      titleMedium: titleMedium(primaryColor),
      titleSmall: titleSmall(primaryColor),
      bodyLarge: bodyLarge(primaryColor),
      bodyMedium: bodyMedium(primaryColor),
      bodySmall: bodySmall(primaryColor),
      labelLarge: labelLarge(primaryColor),
      labelMedium: labelMedium(primaryColor),
      labelSmall: labelSmall(primaryColor),
    );
  }
}
