import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/dashboard_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/student_list_controller.dart';
import 'screens/auth_gate.dart';
import 'services/backend/pocketbase_client.dart';

/// 应用入口 - 初始化 PocketBase 并启动应用
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializePocketBase();

  runApp(const AppProviders(child: MyApp()));
}

class AppProviders extends StatelessWidget {
  const AppProviders({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()..initialize()),
        ChangeNotifierProvider(create: (_) => DashboardController()..load()),
        ChangeNotifierProvider(create: (_) => HomeController()..initialize()),
        ChangeNotifierProvider(
          create: (_) => StudentListController()..loadStudents(),
        ),
      ],
      child: child,
    );
  }
}

/// 应用主体
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '幼儿园图书管理',
      theme: ThemeData(
        primarySwatch: Colors.green,
        // 优化Material 3主题
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        // 设置输入框主题
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      debugShowCheckedModeBanner: false, // 隐藏调试标签
      // 使用AuthGate作为应用入口，自动管理认证状态
      home: const AuthGate(),
    );
  }
}
