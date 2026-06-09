import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/controllers/auth_controller.dart';
import 'package:kindergarten_library/screens/auth_gate.dart';
import 'package:kindergarten_library/screens/main_navigation.dart';
import 'package:kindergarten_library/services/backend/pocketbase_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializePocketBase();
  });

  testWidgets('AuthGate shows main navigation when signed in', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: _TestAuthController(),
        child: _testApp(
          home: AuthGate(
            mainNavigationBuilder: (_) => const MainNavigationScreen(
              pages: [
                Center(child: Text('仪表盘页')),
                Center(child: Text('图书页')),
                Center(child: Text('学生页')),
                Center(child: Text('我的页')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MainNavigationScreen), findsOneWidget);
    expect(find.text('仪表盘'), findsWidgets);
  });

  testWidgets('AuthGate shows initialization error with retry', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: _ErrorAuthController(),
        child: _testApp(home: const AuthGate()),
      ),
    );

    expect(find.text('初始化失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('MainNavigation keeps tab page state', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: _TestAuthController(),
        child: _testApp(
          home: const MainNavigationScreen(
            pages: [
              Center(child: Text('仪表盘页')),
              _FakeSearchTab(),
              Center(child: Text('学生页')),
              Center(child: Text('我的页')),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('图书'));
    await tester.pump();

    final searchField = find.widgetWithText(TextField, '测试搜索');
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, '小熊');
    await tester.pump();
    expect(tester.widget<TextField>(searchField).controller?.text, '小熊');

    await tester.tap(find.text('学生'));
    await tester.pump();
    await tester.tap(find.text('图书'));
    await tester.pump();

    expect(tester.widget<TextField>(searchField).controller?.text, '小熊');
  });
}

Widget _testApp({required Widget home}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
    ),
    home: home,
  );
}

class _TestAuthController extends AuthController {
  _TestAuthController() : super(authStateChanges: const Stream.empty());

  @override
  bool get isInitializing => false;

  @override
  bool get isLoggedIn => true;

  @override
  bool get isAdmin => true;

  @override
  String get displayName => '测试老师';

  @override
  String get roleDisplayName => '超级管理员';

  @override
  String? get currentUserEmail => 'teacher@example.com';

  @override
  String? get currentUserId => 'test-user';

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> signOut() async {}
}

class _ErrorAuthController extends _TestAuthController {
  @override
  bool get isLoggedIn => false;

  @override
  String? get errorMessage => '无法连接认证服务';

  @override
  Future<void> initialize() async {}
}

class _FakeSearchTab extends StatefulWidget {
  const _FakeSearchTab();

  @override
  State<_FakeSearchTab> createState() => _FakeSearchTabState();
}

class _FakeSearchTabState extends State<_FakeSearchTab> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: '测试搜索'),
      ),
    );
  }
}
