import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../utils/snackbar_helper.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Name fields
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _birthdateCtrl = TextEditingController();

  // Location fields
  final _cityCtrl = TextEditingController();
  final _regionCtrl =
      TextEditingController(); // Optional: State/Province/Region

  DateTime? _selectedBirthdateRaw;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _birthdateCtrl.dispose();
    _cityCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          SnackbarHelper.showError(
              context, 'No se pudo abrir el enlace: $urlString');
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Error al intentar abrir el enlace');
      }
    }
  }

  Future<void> _selectBirthdate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      helpText: 'Selecciona tu fecha de nacimiento',
    );

    if (date != null) {
      setState(() {
        _selectedBirthdateRaw = date;
        _birthdateCtrl.text = '${date.day}/${date.month}/${date.year}';
      });
    }
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      SnackbarHelper.showWarning(
          context, 'Debes aceptar los términos y condiciones');
      return;
    }

    final isoDate = _selectedBirthdateRaw!.toIso8601String().split('T')[0];

    // Concatenate Name (Safe)
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final fullName = [first, last]
        .where((s) => s.isNotEmpty && s.toLowerCase() != "null")
        .join(" ");

    // Format Location
    final city = _cityCtrl.text.trim();
    final region = _regionCtrl.text.trim();
    final fullLocation = region.isNotEmpty ? '$city, $region' : city;

    // Escuchar el estado antes de llamar al registro para reaccionar al éxito
    final notifier = ref.read(authProvider.notifier);

    await notifier.register(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      birthdateIso: isoDate,
      city: fullLocation,
      name: fullName,
    );

    if (mounted) {
      final status = ref.read(authProvider).status;
      if (status == AuthStatus.pendingVerification) {
        // Cerramos el registro y nos aseguramos de que el AuthGate muestre el código
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Crear cuenta"),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset('assets/app_icon.png', height: 100),
                  const SizedBox(height: 12),
                  Text('Únete a Celestya',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Encuentra tu media naranja',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- Name Section ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Min 2 letras';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Apellido *',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().length < 2) {
                        return 'Min 2 letras';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 4),
              child: Text(
                'Como aparecerá en tu perfil',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Correo electrónico *',
                  prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El correo es requerido';
                }
                if (!v.contains('@')) return 'Correo inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // --- Location Section ---
            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                  labelText: 'Ciudad *',
                  prefixIcon: Icon(Icons.location_city_outlined),
                  helperText: 'Donde vives actualmente'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'La ciudad es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _regionCtrl,
              decoration: const InputDecoration(
                  labelText: 'Estado / Provincia / Región (Opcional)',
                  prefixIcon: Icon(Icons.map_outlined),
                  helperText: 'Ayuda a mejorar la búsqueda'),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _birthdateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                  labelText: 'Fecha de nacimiento *',
                  prefixIcon: Icon(Icons.cake_outlined),
                  helperText: 'Debes ser mayor de 18 años',
                  suffixIcon: Icon(Icons.calendar_today)),
              onTap: _selectBirthdate,
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'La fecha de nacimiento es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                helperText: 'Mínimo 8 caracteres',
              ),
              validator: (v) {
                if (v == null || v.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                return null;
              },
            ),
            const SizedBox(height: 24),

            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text.rich(
                TextSpan(
                  text: 'Acepto los ',
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: 'Términos y Condiciones',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap =
                            () => _launchURL('https://celestya.app/terms'),
                    ),
                    const TextSpan(text: ' y la '),
                    TextSpan(
                      text: 'Política de Privacidad',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap =
                            () => _launchURL('https://celestya.app/privacy'),
                    ),
                  ],
                ),
              ),
            ),
            if (authState.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(authState.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 24),

            FilledButton(
              onPressed: authState.isLoading ? null : _register,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Crear cuenta'),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¿Ya tienes cuenta? ', style: theme.textTheme.bodyMedium),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Inicia sesión')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
