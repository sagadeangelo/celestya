// lib/core/widgets/celestya_input.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';

/// TextField personalizado de Celestya con validación y estilos consistentes
class CelestyaInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;

  const CelestyaInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
  });

  /// Input para email
  factory CelestyaInput.email({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hint,
    String? errorText,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return CelestyaInput(
      key: key,
      controller: controller,
      label: label ?? 'Correo electrónico',
      hint: hint ?? 'ejemplo@correo.com',
      errorText: errorText,
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa tu correo';
        }
        if (!value.contains('@')) {
          return 'Ingresa un correo válido';
        }
        return null;
      },
    );
  }

  /// Input para contraseña
  factory CelestyaInput.password({
    Key? key,
    TextEditingController? controller,
    String? label,
    String? hint,
    String? errorText,
    bool showPassword = false,
    VoidCallback? onToggleVisibility,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return CelestyaInput(
      key: key,
      controller: controller,
      label: label ?? 'Contraseña',
      hint: hint,
      errorText: errorText,
      prefixIcon: Icons.lock_outline,
      suffixIcon: showPassword ? Icons.visibility_off : Icons.visibility,
      onSuffixIconTap: onToggleVisibility,
      obscureText: !showPassword,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa tu contraseña';
        }
        if (value.length < 6) {
          return 'La contraseña debe tener al menos 6 caracteres';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      enabled: enabled,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(suffixIcon),
                onPressed: onSuffixIconTap,
              )
            : null,
      ),
    );
  }
}
