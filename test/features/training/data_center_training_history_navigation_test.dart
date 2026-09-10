import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';

void main() {
  testWidgets('History exposes and opens Training History analytics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const DataCenterHistoryPage(),
        routes: {
          AppRoutes.trainingAnalyticsHistory: (_) =>
              const Scaffold(body: Text('TRAINING ANALYTICS ROUTE')),
        },
      ),
    );

    expect(find.text('BODY HISTORY'), findsOneWidget);
    expect(find.text('NUTRITION HISTORY'), findsOneWidget);
    expect(find.text('TRAINING HISTORY'), findsOneWidget);
    for (final label in [
      'OPEN BODY HISTORY',
      'OPEN NUTRITION HISTORY',
      'OPEN TRAINING HISTORY',
    ]) {
      final button = find.widgetWithText(OperationButton, label);
      expect(
        tester.widget<OperationButton>(button).role,
        OperationActionRole.primary,
      );
      final actionColor = Theme.of(tester.element(button)).colorScheme.primary;
      expect(
        tester
            .widget<Text>(
              find.descendant(of: button, matching: find.text(label)),
            )
            .style
            ?.color,
        actionColor,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: button, matching: find.byType(Icon)),
            )
            .color,
        actionColor,
      );
    }

    await tester.tap(find.text('OPEN TRAINING HISTORY'));
    await tester.pumpAndSettle();

    expect(find.text('TRAINING ANALYTICS ROUTE'), findsOneWidget);
  });
}
