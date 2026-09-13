import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';

void main() {
  testWidgets('History exposes Digestive History after existing entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const DataCenterHistoryPage(),
        routes: {
          AppRoutes.bodyHistory: (_) => const Scaffold(body: Text('BODY')),
          AppRoutes.nutritionHistory: (_) =>
              const Scaffold(body: Text('NUTRITION')),
          AppRoutes.trainingAnalyticsHistory: (_) =>
              const Scaffold(body: Text('TRAINING')),
          AppRoutes.digestiveHistory: (_) =>
              const Scaffold(body: Text('DIGESTIVE ROUTE')),
        },
      ),
    );

    expect(find.text('DIGESTIVE HISTORY'), findsOneWidget);
    await tester.tap(find.text('OPEN DIGESTIVE HISTORY'));
    await tester.pumpAndSettle();
    expect(find.text('DIGESTIVE ROUTE'), findsOneWidget);
  });
}
