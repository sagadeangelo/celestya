// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart'; // 👈 Importar Splash
import 'app_shell.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'models/quiz_attempt.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Background sync logic will go here
    return await SyncService.processQueue();
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(QuizAttemptAdapter());
  await Hive.openBox<QuizAttempt>('quiz_attempts');

  // 2. Initialize Workmanager
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set to false for production
  );

  // 3. Initialize Connectivity Listener
  ConnectivityService.init();

  // 4. Initial sync attempt
  SyncService.triggerSync();

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
