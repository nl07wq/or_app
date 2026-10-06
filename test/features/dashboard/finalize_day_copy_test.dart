import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/widgets/daily_log_card.dart';

void main() {
  test(
    'FINALIZE DAY confirmation copy retains its Japanese text with required uppercase labels',
    () {
      expect(finalizeDayConfirmationCopy, contains('DAILY DEBRIEF'));
      expect(finalizeDayConfirmationCopy, contains('OPERATION DATE'));
      expect(finalizeDayConfirmationCopy, isNot(contains('Daily Debrief')));
      expect(finalizeDayConfirmationCopy, isNot(contains('Operation Date')));
    },
  );

  testWidgets('FINALIZE DAY confirmation copy fits supported widths', (
    tester,
  ) async {
    for (final width in <double>[320, 390, 900]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('FINALIZE DAY'),
                    content: const Text(finalizeDayConfirmationCopy),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('YES'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('NO'),
                      ),
                    ],
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      expect(find.text(finalizeDayConfirmationCopy), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('NO'));
      await tester.pumpAndSettle();
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
