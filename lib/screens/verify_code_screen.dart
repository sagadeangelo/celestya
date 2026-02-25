import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/auth_api.dart';

class VerifyCodeScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyCodeScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isResending = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final code = _codeCtrl.text.trim();

    // Attempt verification
    await ref.read(authProvider.notifier).verifyCode(code);

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.loggedIn) {
      // Success: Navigate to AuthGate to route to AppShell
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Verificación exitosa! Entrando...')),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, '/auth_gate', (route) => false);
    }
  }

  void _resendCode() async {
    setState(() => _isResending = true);
    try {
      final res = await AuthApi.resendVerification(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Código reenviado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verificar cuenta"),
        actions: [
          IconButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            tooltip: "Cancelar / Salir",
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.mark_email_read_outlined,
                size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              "Ingresa el código que enviamos a tu correo",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              // Explicit color to avoid visibility issues
              style: TextStyle(
                fontSize: 32,
                letterSpacing: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                counterText: "",
                hintText: "000000",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: theme.cardColor,
              ),
              onChanged: (val) {
                // Auto-submit when user types 6 digits
                if (val.length == 6) {
                  _verify();
                }
              },
              validator: (v) {
                if (v == null || v.length != 6) {
                  return "El código debe ser de 6 dígitos";
                }
                if (int.tryParse(v) == null) return "Solo números";
                return null;
              },
            ),
            if (authState.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                authState.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: authState.isLoading ? null : _verify,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Verificar código"),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isResending ? null : _resendCode,
              child: _isResending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Reenviar código"),
            ),
            const SizedBox(height: 8),
            Text(
              "También puedes verificar haciendo clic en el enlace del correo.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
