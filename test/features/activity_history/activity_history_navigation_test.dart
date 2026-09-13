import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/body_history/pages/data_center_history_page.dart';

void main() {
  testWidgets('Data Center History keeps entries ordered and routes intact', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = const Size(900, 3000)
      ..devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: const DataCenterHistoryPage(),
        routes: {
          AppRoutes.bodyHistory: (_) =>
              const Scaffold(body: Text('BODY ROUTE')),
          AppRoutes.nutritionHistory: (_) =>
              const Scaffold(body: Text('NUTRITION ROUTE')),
          AppRoutes.trainingAnalyticsHistory: (_) =>
              const Scaffold(body: Text('TRAINING ROUTE')),
          AppRoutes.activityHistory: (_) =>
              const Scaffold(body: Text('ACTIVITY ROUTE')),
          AppRoutes.sleepHistory: (_) =>
              const Scaffold(body: Text('SLEEP ROUTE')),
          AppRoutes.digestiveHistory: (_) =>
              const Scaffold(body: Text('DIGESTIVE ROUTE')),
        },
      ),
    );
    await tester.pumpAndSettle();

    final titles = [
      'BODY HISTORY',
      'NUTRITION HISTORY',
      'TRAINING HISTORY',
      'ACTIVITY HISTORY',
      'SLEEP HISTORY',
      'DIGESTIVE HISTORY',
    ];
    for (var index = 1; index < titles.length; index += 1) {
      expect(
        tester.getTopLeft(find.text(titles[index - 1])).dy,
        lessThan(tester.getTopLeft(find.text(titles[index])).dy),
      );
    }

    for (final route in const [
      ('OPEN BODY HISTORY', 'BODY ROUTE'),
      ('OPEN NUTRITION HISTORY', 'NUTRITION ROUTE'),
      ('OPEN TRAINING HISTORY', 'TRAINING ROUTE'),
      ('OPEN ACTIVITY HISTORY', 'ACTIVITY ROUTE'),
      ('OPEN SLEEP HISTORY', 'SLEEP ROUTE'),
      ('OPEN DIGESTIVE HISTORY', 'DIGESTIVE ROUTE'),
    ]) {
      final button = find.widgetWithText(OperationButton, route.$1);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(route.$2), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });
}
