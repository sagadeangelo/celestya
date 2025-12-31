import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  void _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa correo y contraseña')));
      return;
    }

    setState(() => _loading = true);
    try {
      final token = await AuthApi.login(email, pass);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/app');
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Iniciar sesión")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          // Scroll por si pantallas peques
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo en Login
              Hero(
                tag:
                    'app_logo', // Hero animation desde Splash si se pudiera, o solo efecto
                child: Image.asset(
                  'assets/app_icon.png',
                  height: 120, // Visible y elegante
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Celestya",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: "Correo",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Entrar"),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text("Crear cuenta"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
