import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

/// 认证网关 - App 的入口
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.mainNavigationBuilder});

  final WidgetBuilder? mainNavigationBuilder;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isInitializing) {
      return _buildLoading();
    }

    if (auth.errorMessage != null && !auth.isLoggedIn) {
      return _buildError(context, auth.errorMessage!);
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    return mainNavigationBuilder?.call(context) ?? const MainNavigationScreen();
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

  Widget _buildError(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red[400]),
              const SizedBox(height: 16),
              const Text(
                '初始化失败',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.read<AuthController>().initialize(),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
