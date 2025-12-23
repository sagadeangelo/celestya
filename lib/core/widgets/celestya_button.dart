// lib/core/widgets/celestya_button.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Tamaños disponibles para botones
enum CelestyaButtonSize {
  small,
  medium,
  large,
}

/// Botón principal de Celestya con variantes y estados
class CelestyaButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CelestyaButtonSize size;
  final bool isLoading;
  final IconData? icon;
  final bool iconRight;

  const CelestyaButton({
    super.key,
    required this.text,
    this.onPressed,
    this.size = CelestyaButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.iconRight = false,
  });

  /// Botón primario (FilledButton)
  const CelestyaButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.size = CelestyaButtonSize.medium,
    this.isLoading = false,
    this.icon,
    this.iconRight = false,
  });

  /// Botón secundario (ElevatedButton)
  factory CelestyaButton.secondary({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    CelestyaButtonSize size = CelestyaButtonSize.medium,
    bool isLoading = false,
    IconData? icon,
    bool iconRight = false,
  }) {
    return _CelestyaSecondaryButton(
      key: key,
      text: text,
      onPressed: onPressed,
      size: size,
      isLoading: isLoading,
      icon: icon,
      iconRight: iconRight,
    );
  }

  /// Botón outline (OutlinedButton)
  factory CelestyaButton.outline({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    CelestyaButtonSize size = CelestyaButtonSize.medium,
    bool isLoading = false,
    IconData? icon,
    bool iconRight = false,
  }) {
    return _CelestyaOutlineButton(
      key: key,
      text: text,
      onPressed: onPressed,
      size: size,
      isLoading: isLoading,
      icon: icon,
      iconRight: iconRight,
    );
  }

  /// Botón de texto (TextButton)
  factory CelestyaButton.text({
    Key? key,
    required String text,
    VoidCallback? onPressed,
    CelestyaButtonSize size = CelestyaButtonSize.medium,
    bool isLoading = false,
    IconData? icon,
    bool iconRight = false,
  }) {
    return _CelestyaTextButton(
      key: key,
      text: text,
      onPressed: onPressed,
      size: size,
      isLoading: isLoading,
      icon: icon,
      iconRight: iconRight,
    );
  }

  double get _height {
    switch (size) {
      case CelestyaButtonSize.small:
        return DesignTokens.buttonHeightSmall;
      case CelestyaButtonSize.medium:
        return DesignTokens.buttonHeightMedium;
      case CelestyaButtonSize.large:
        return DesignTokens.buttonHeightLarge;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case CelestyaButtonSize.small:
        return EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space2,
        );
      case CelestyaButtonSize.medium:
        return EdgeInsets.symmetric(
          horizontal: DesignTokens.space5,
          vertical: DesignTokens.space3,
        );
      case CelestyaButtonSize.large:
        return EdgeInsets.symmetric(
          horizontal: DesignTokens.space6,
          vertical: DesignTokens.space4,
        );
    }
  }

  Widget _buildContent() {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white.withOpacity(0.9),
          ),
        ),
      );
    }

    if (icon == null) {
      return Text(text);
    }

    final iconWidget = Icon(icon, size: DesignTokens.iconMedium);
    final textWidget = Text(text);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: iconRight
          ? [textWidget, SizedBox(width: DesignTokens.space2), iconWidget]
          : [iconWidget, SizedBox(width: DesignTokens.space2), textWidget],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }
}

// Variantes privadas
class _CelestyaSecondaryButton extends CelestyaButton {
  const _CelestyaSecondaryButton({
    super.key,
    required super.text,
    super.onPressed,
    super.size,
    super.isLoading,
    super.icon,
    super.iconRight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }
}

class _CelestyaOutlineButton extends CelestyaButton {
  const _CelestyaOutlineButton({
    super.key,
    required super.text,
    super.onPressed,
    super.size,
    super.isLoading,
    super.icon,
    super.iconRight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }
}

class _CelestyaTextButton extends CelestyaButton {
  const _CelestyaTextButton({
    super.key,
    required super.text,
    super.onPressed,
    super.size,
    super.isLoading,
    super.icon,
    super.iconRight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      ),
    );
  }
}
