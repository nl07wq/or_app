import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/commander_report_paper_card.dart';

void main() {
  testWidgets('uses the shared repeating paper texture with readable ink', (
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

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('commander-report-paper-surface')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(
      decoration.image!.image,
      const AssetImage('assets/images/textures/commander_report_paper.jpg'),
    );
    expect(decoration.image!.repeat, ImageRepeat.repeat);
    expect(tester.widget<Text>(find.text('REPORT')).style, isNull);
    expect(Theme.of(tester.element(find.text('REPORT'))).colorScheme.onSurface,
        const Color(0xFF292822));
  });
}
