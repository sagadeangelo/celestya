import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';
import 'verify_code_screen.dart';
import '../app_shell.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    
    print('[AuthGate] Building with status: ${authState.status}, email: ${authState.email}');

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (authState.status) {
      case AuthStatus.loggedIn:
        print('[AuthGate] Showing AppShell');
        // Disparar sincronización inteligente
        SyncService.triggerSync();
        return const AppShell(); // Or wherever /app leads
      case AuthStatus.pendingVerification:
        print('[AuthGate] Showing VerifyCodeScreen for ${authState.email}');
        return VerifyCodeScreen(email: authState.email ?? "");
      case AuthStatus.loggedOut:
        print('[AuthGate] Showing LoginScreen');
        return const LoginScreen();
    }
  }
}
