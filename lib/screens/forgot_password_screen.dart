import 'package:flutter/material.dart';
import '../services/auth_api.dart';
import '../core/widgets/celestya_button.dart';
import '../core/widgets/celestya_input.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthApi.forgotPassword(_emailCtrl.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Recuperar contraseña")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _sent
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mark_email_read,
                      size: 80, color: Colors.green),
                  const SizedBox(height: 20),
                  Text(
                    "¡Enlace enviado!",
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Si el correo ${_emailCtrl.text} está registrado, recibirás intrucciones para restablecer tu contraseña.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                  CelestyaButton(
                    text: "Volver a Iniciar Sesión",
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.",
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    CelestyaInput.email(
                      label: "Correo electrónico",
                      controller: _emailCtrl,
                    ),
                    const SizedBox(height: 30),
                    CelestyaButton(
                      text: "Enviar enlace",
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
