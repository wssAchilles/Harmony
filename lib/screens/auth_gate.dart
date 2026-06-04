import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

/// 认证网关 - App 的入口
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  late Future<void> _initialAuthState;

  @override
  void initState() {
    super.initState();
    _initialAuthState = _authService.initializeUserState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialAuthState,
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        return StreamBuilder<bool>(
          stream: _authService.authStateChanges,
          initialData: _authService.isLoggedIn,
          builder: (context, snapshot) {
            final isLoggedIn = snapshot.data ?? _authService.isLoggedIn;
            if (!isLoggedIn) {
              _authService.onUserLoggedOut();
              return const LoginScreen();
            }

            return const MainNavigationScreen();
          },
        );
      },
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 16),
            Text(
              '正在初始化...',
              style: TextStyle(color: Colors.green[700], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
