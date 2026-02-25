import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/sync_service.dart';
import 'login_screen.dart';
import 'verify_code_screen.dart';
import '../app_shell.dart';

import '../services/api_client.dart';
import 'login_screen.dart';
import 'verify_code_screen.dart';
import '../app_shell.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _isCheckingConnectivity = true;
  String? _connectivityError;

  @override
  void initState() {
    super.initState();
    _performConnectivityCheck();
  }

  Future<void> _performConnectivityCheck() async {
    setState(() {
      _isCheckingConnectivity = true;
      _connectivityError = null;
    });

    final result = await ApiClient.checkConnectivity();

    if (mounted) {
      setState(() {
        _isCheckingConnectivity = false;
        if (!result['ok']) {
          _connectivityError =
              result['message'] ?? result['error'] ?? 'Error de red';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingConnectivity) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final authState = ref.watch(authProvider);

    print(
        '[AuthGate] Building with status: ${authState.status}, email: ${authState.email}');

    Widget body;
    if (authState.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      switch (authState.status) {
        case AuthStatus.loggedIn:
          print('[AuthGate] Showing AppShell');
          SyncService.triggerSync();
          body = const AppShell();
          break;
        case AuthStatus.pendingVerification:
          print('[AuthGate] Showing VerifyCodeScreen for ${authState.email}');
          body = VerifyCodeScreen(email: authState.email ?? "");
          break;
        case AuthStatus.loggedOut:
          print('[AuthGate] Showing LoginScreen');
          body = const LoginScreen();
          break;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          body,
          if (_connectivityError != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 20,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                color: Colors.redAccent,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No hay conexión con servidor: $_connectivityError',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _performConnectivityCheck,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
