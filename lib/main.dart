// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/language_service.dart';
import 'providers/language_provider.dart';

import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/splash_screen.dart'; // 👈 Importar Splash
import 'app_shell.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'models/quiz_attempt.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/deep_link_service.dart';
import 'providers/auth_provider.dart';

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

  // 2. Initialize Workmanager (Not supported on Web)
  if (!kIsWeb) {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode, // Use flutter foundation to detect mode
    );
  }

  // 3. Initialize Connectivity Listener
  ConnectivityService.init();

  // 4. Initial sync attempt
  SyncService.triggerSync();

  // 5. Initialize SharedPreferences for Language
  final prefs = await SharedPreferences.getInstance();
  final languageService = LanguageService(prefs);

  runApp(
    ProviderScope(
      overrides: [
        languageServiceProvider.overrideWithValue(languageService),
      ],
      child: const CelestyaApp(),
    ),
  );
}

class CelestyaApp extends ConsumerStatefulWidget {
  const CelestyaApp({super.key});

  @override
  ConsumerState<CelestyaApp> createState() => _CelestyaAppState();
}

class _CelestyaAppState extends ConsumerState<CelestyaApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Initialize deep link service
    DeepLinkService.initialize(
      onVerified: (email, token) async {
        // Trigger auto-login with magic link token
        if (token != null) {
          await ref
              .read(authProvider.notifier)
              .handleDeepLinkLogin(email, token);
        } else if (email != null) {
          // Fallback legacy behavior if no token exists
          final context = navigatorKey.currentContext;
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Cuenta $email verificada. Por favor, inicia sesión.')));
          }
        }
      },
      onResetPassword: (token) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(token: token),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    DeepLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = ref.watch(languageProvider);

    return MaterialApp(
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      navigatorKey: navigatorKey,
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
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/register': (_) => const RegisterScreen(),
        '/app': (_) => const AppShell(),
      },
    );
  }
}
