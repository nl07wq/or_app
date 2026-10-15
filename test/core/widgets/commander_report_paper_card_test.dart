import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/commander_report_paper_card.dart';
import 'package:or_app/core/widgets/dashboard_glass_card.dart';

void main() {
  testWidgets('restores the shared Dashboard glass report surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: CommanderReportPaperCard(child: Text('REPORT')),
        ),
      ),
    );

    expect(find.byType(DashboardGlassCard), findsOneWidget);
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('commander-report-paper-surface')),
    );
    expect(surface.decoration, isNull);
    expect(tester.widget<Text>(find.text('REPORT')).style, isNull);
    expect(
      Theme.of(tester.element(find.text('REPORT'))).colorScheme.onSurface,
      ThemeData.dark().colorScheme.onSurface,
    );
  });
}
