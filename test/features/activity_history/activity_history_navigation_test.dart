import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';

void main() {
  testWidgets('Data Center History opens Activity History', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const DataCenterHistoryPage(),
        routes: {
          AppRoutes.activityHistory: (_) =>
              const Scaffold(body: Text('ACTIVITY ROUTE')),
        },
      ),
    );

    await tester.scrollUntilVisible(find.text('OPEN ACTIVITY HISTORY'), 240);
    final button = find.widgetWithText(
      OperationButton,
      'OPEN ACTIVITY HISTORY',
    );
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('ACTIVITY ROUTE'), findsOneWidget);
  });
}
