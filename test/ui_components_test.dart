import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kindergarten_library/ui/widgets/async_action_button.dart';
import 'package:kindergarten_library/ui/widgets/error_state_view.dart';
import 'package:kindergarten_library/ui/widgets/section_card.dart';
import 'package:kindergarten_library/ui/widgets/status_chip.dart';

void main() {
  testWidgets('AsyncActionButton switches between idle and loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncActionButton(onPressed: () {}, label: '提交'),
        ),
      ),
    );

    expect(find.text('提交'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AsyncActionButton(
            onPressed: null,
            label: '提交',
            state: AsyncActionState.loading,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('StatusChip updates label and colors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusChip(
            label: '可借',
            backgroundColor: Colors.green.shade100,
            foregroundColor: Colors.green.shade800,
          ),
        ),
      ),
    );

    expect(find.text('可借'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusChip(
            label: '全部借出',
            backgroundColor: Colors.orange.shade100,
            foregroundColor: Colors.orange.shade800,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部借出'), findsOneWidget);
  });

  testWidgets('SectionCard keeps content padded and handles taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SectionCard(
            onTap: () => taps += 1,
            child: const Text('账户信息'),
          ),
        ),
      ),
    );

    expect(find.text('账户信息'), findsOneWidget);

    await tester.tap(find.text('账户信息'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('ErrorStateView shows retry action', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorStateView(
            title: '加载失败',
            message: '网络不可用',
            onRetry: () => retries += 1,
          ),
        ),
      ),
    );

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('网络不可用'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(retries, 1);
  });
}
