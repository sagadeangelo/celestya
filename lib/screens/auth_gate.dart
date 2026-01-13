import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Intentar login automático
    final success = await AuthService.tryAutoLogin();
    
    if (mounted) {
      if (success) {
        // Disparar sincronización inteligente (Prompt 5)
        SyncService.triggerSync();
        
        // Si el login es exitoso, navegar a la app principal
        Navigator.pushReplacementNamed(context, '/app');
      } else {
        // Si falla, mostrar pantalla de login
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Si no está cargando y no navegó (falló login), mostrar LoginScreen
    return const LoginScreen();
  }
}
