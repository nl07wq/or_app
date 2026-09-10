import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
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

    await tester.tap(find.text('OPEN TRAINING HISTORY'));
    await tester.pumpAndSettle();

    expect(find.text('TRAINING ANALYTICS ROUTE'), findsOneWidget);
  });
}
