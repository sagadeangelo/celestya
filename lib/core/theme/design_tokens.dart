// lib/core/theme/design_tokens.dart

/// Sistema de tokens de diseño para Celestya
/// Proporciona valores consistentes para espaciado, radios, elevaciones y animaciones
class DesignTokens {
  // ============================================
  // SPACING SYSTEM (4pt grid)
  // ============================================
  /// 4px - Espaciado mínimo
  static const double space1 = 4.0;
  
  /// 8px - Espaciado pequeño
  static const double space2 = 8.0;
  
  /// 12px - Espaciado medio-pequeño
  static const double space3 = 12.0;
  
  /// 16px - Espaciado medio (más común)
  static const double space4 = 16.0;
  
  /// 20px - Espaciado medio-grande
  static const double space5 = 20.0;
  
  /// 24px - Espaciado grande
  static const double space6 = 24.0;
  
  /// 32px - Espaciado extra grande
  static const double space8 = 32.0;
  
  /// 40px - Espaciado muy grande
  static const double space10 = 40.0;
  
  /// 48px - Espaciado máximo
  static const double space12 = 48.0;

  // ============================================
  // BORDER RADIUS
  // ============================================
  /// 8px - Radio pequeño
  static const double radiusXSmall = 8.0;
  
  /// 12px - Radio pequeño-medio
  static const double radiusSmall = 12.0;
  
  /// 16px - Radio medio
  static const double radiusMedium = 16.0;
  
  /// 18px - Radio medio-grande (botones, inputs)
  static const double radiusLarge = 18.0;
  
  /// 24px - Radio grande (cards)
  static const double radiusXLarge = 24.0;
  
  /// 28px - Radio extra grande (match cards)
  static const double radiusXXLarge = 28.0;

  // ============================================
  // ELEVATION / SHADOWS
  // ============================================
  /// Elevación baja - 2px
  static const double elevationLow = 2.0;
  
  /// Elevación media-baja - 4px
  static const double elevationMediumLow = 4.0;
  
  /// Elevación media - 8px
  static const double elevationMedium = 8.0;
  
  /// Elevación alta - 12px
  static const double elevationHigh = 12.0;
  
  /// Elevación muy alta - 16px
  static const double elevationVeryHigh = 16.0;

  // ============================================
  // ANIMATION DURATIONS
  // ============================================
  /// Animación muy rápida - 100ms
  static const Duration durationFast = Duration(milliseconds: 100);
  
  /// Animación rápida - 200ms
  static const Duration durationNormal = Duration(milliseconds: 200);
  
  /// Animación media - 300ms
  static const Duration durationMedium = Duration(milliseconds: 300);
  
  /// Animación lenta - 500ms
  static const Duration durationSlow = Duration(milliseconds: 500);

  // ============================================
  // ICON SIZES
  // ============================================
  /// Icono pequeño - 16px
  static const double iconSmall = 16.0;
  
  /// Icono medio - 20px
  static const double iconMedium = 20.0;
  
  /// Icono grande - 24px
  static const double iconLarge = 24.0;
  
  /// Icono extra grande - 32px
  static const double iconXLarge = 32.0;

  // ============================================
  // BUTTON SIZES
  // ============================================
  /// Altura de botón pequeño
  static const double buttonHeightSmall = 36.0;
  
  /// Altura de botón medio
  static const double buttonHeightMedium = 48.0;
  
  /// Altura de botón grande
  static const double buttonHeightLarge = 56.0;

  // ============================================
  // AVATAR SIZES
  // ============================================
  /// Avatar extra pequeño - 24px
  static const double avatarXSmall = 24.0;
  
  /// Avatar pequeño - 32px
  static const double avatarSmall = 32.0;
  
  /// Avatar medio - 48px
  static const double avatarMedium = 48.0;
  
  /// Avatar grande - 64px
  static const double avatarLarge = 64.0;
  
  /// Avatar extra grande - 96px
  static const double avatarXLarge = 96.0;
  
  /// Avatar muy grande - 120px
  static const double avatarXXLarge = 120.0;

  // ============================================
  // OPACITY VALUES
  // ============================================
  /// Opacidad muy baja - 10%
  static const double opacityVeryLow = 0.1;
  
  /// Opacidad baja - 25%
  static const double opacityLow = 0.25;
  
  /// Opacidad media - 50%
  static const double opacityMedium = 0.5;
  
  /// Opacidad alta - 75%
  static const double opacityHigh = 0.75;
  
  /// Opacidad muy alta - 90%
  static const double opacityVeryHigh = 0.9;
}
