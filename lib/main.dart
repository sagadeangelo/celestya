// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart'; // 👈 Importar Splash
import 'app_shell.dart';

void main() {
  runApp(
    // Envolver la app con ProviderScope para habilitar Riverpod
    const ProviderScope(
      child: CelestyaApp(),
    ),
  );
}

class CelestyaApp extends StatelessWidget {
  const CelestyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Celestya',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      
      // 👇 Ahora empezamos en el Splash
      home: const SplashScreen(),
      
      routes: {
        '/auth_gate': (_) => const AuthGate(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/app': (_) => const AppShell(),
      },
    );
  }
}
