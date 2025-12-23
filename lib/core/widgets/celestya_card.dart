// lib/core/widgets/celestya_card.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Variantes de card disponibles
enum CelestyaCardVariant {
  elevated,
  outlined,
  filled,
}

/// Card reutilizable de Celestya con variantes
class CelestyaCard extends StatelessWidget {
  final Widget child;
  final CelestyaCardVariant variant;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? color;

  const CelestyaCard({
    super.key,
    required this.child,
    this.variant = CelestyaCardVariant.elevated,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  });

  /// Card elevado (por defecto)
  const CelestyaCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  }) : variant = CelestyaCardVariant.elevated;

  /// Card con borde
  const CelestyaCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  }) : variant = CelestyaCardVariant.outlined;

  /// Card con fondo de color
  const CelestyaCard.filled({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  }) : variant = CelestyaCardVariant.filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final defaultPadding = EdgeInsets.all(DesignTokens.space4);
    final defaultMargin = EdgeInsets.symmetric(
      horizontal: DesignTokens.space4,
      vertical: DesignTokens.space2,
    );

    Widget cardContent = Padding(
      padding: padding ?? defaultPadding,
      child: child,
    );

    final borderRadius = BorderRadius.circular(DesignTokens.radiusXLarge);

    switch (variant) {
      case CelestyaCardVariant.elevated:
        return Container(
          margin: margin ?? defaultMargin,
          child: Material(
            color: color ?? theme.cardColor,
            elevation: DesignTokens.elevationMedium,
            borderRadius: borderRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: cardContent,
            ),
          ),
        );

      case CelestyaCardVariant.outlined:
        return Container(
          margin: margin ?? defaultMargin,
          decoration: BoxDecoration(
            color: color ?? theme.cardColor,
            borderRadius: borderRadius,
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: cardContent,
          ),
        );

      case CelestyaCardVariant.filled:
        return Container(
          margin: margin ?? defaultMargin,
          decoration: BoxDecoration(
            color: color ?? theme.colorScheme.surfaceContainerHighest,
            borderRadius: borderRadius,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: cardContent,
          ),
        );
    }
  }
}
