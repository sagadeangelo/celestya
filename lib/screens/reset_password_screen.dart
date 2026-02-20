import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../core/widgets/celestya_button.dart';
import '../core/widgets/celestya_input.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Las contraseñas no coinciden")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthApi.resetPassword(widget.token, _passCtrl.text);
      if (mounted) {
        // Success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("¡Éxito!"),
            content: const Text("Tu contraseña ha sido actualizada."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  // Navigate to login, removing history
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                },
                child: const Text("Iniciar Sesión"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll("Exception: ", "");
        // Cleaner error message logic if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva contraseña")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Crea una contraseña segura.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              CelestyaInput.password(
                label: "Nueva contraseña",
                controller: _passCtrl,
                showPassword: !_obscure1,
                onToggleVisibility: () =>
                    setState(() => _obscure1 = !_obscure1),
              ),
              const SizedBox(height: 20),
              CelestyaInput.password(
                label: "Confirmar contraseña",
                controller: _confirmCtrl,
                showPassword: !_obscure2,
                onToggleVisibility: () =>
                    setState(() => _obscure2 = !_obscure2),
              ),
              const SizedBox(height: 30),
              CelestyaButton(
                text: "Actualizar contraseña",
                isLoading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
