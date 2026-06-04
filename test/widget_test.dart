import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/main.dart';
import 'package:kindergarten_library/services/backend/pocketbase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows login screen when signed out', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await initializePocketBase();

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('幼儿园图书管理系统'), findsOneWidget);
    expect(find.text('立即注册'), findsOneWidget);
  });
}
