import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/navigation/app_routes.dart';
import 'package:or_app/features/command_center/widgets/data_center_page.dart';

void main() {
  testWidgets('TASK-092 Data Center contains History only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: DataCenterPage()),
        routes: {
          AppRoutes.dataCenterHistory: (_) =>
              const Scaffold(body: Text('HISTORY ROUTE')),
        },
      ),
    );

    expect(find.text('DATA CENTER'), findsOneWidget);
    expect(find.text('正式データの履歴と推移を確認します。'), findsOneWidget);
    expect(find.text('HISTORY'), findsNWidgets(2));
    expect(find.text('BACKUP & RESTORE'), findsNothing);
    expect(find.text('SYSTEM MONITORING'), findsNothing);

    await tester.tap(find.text('OPEN HISTORY'));
    await tester.pumpAndSettle();
    expect(find.text('HISTORY ROUTE'), findsOneWidget);
  });
}
