import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/activity_data.dart';
import 'package:or_app/core/models/bowel_movement_record.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/features/activity/activity_entry_page.dart';
import 'package:or_app/features/activity/repository/activity_repository.dart';
import 'package:or_app/features/activity/widgets/bowel_card.dart';
import 'package:or_app/features/morning/morning_fact_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('restored ChoiceChips select none, amounts, and shapes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final amountController = TextEditingController();
    final shapeController = TextEditingController();
    addTearDown(amountController.dispose);
    addTearDown(shapeController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BowelCard(
            amountController: amountController,
            shapeController: shapeController,
          ),
        ),
      ),
    );

    expect(find.byType(ChoiceChip), findsNWidgets(7));

    await tester.tap(find.widgetWithText(ChoiceChip, '少'));
    await tester.pump();
    expect(amountController.text, '1');
    expect(shapeController.text, '1');

    await tester.tap(find.widgetWithText(TextButton, '少'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '普通'));
    await tester.pump();
    expect(amountController.text, '2');

    await tester.tap(find.widgetWithText(TextButton, '普通'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '多'));
    await tester.pump();
    expect(amountController.text, '3');

    await tester.tap(find.widgetWithText(ChoiceChip, '軟便'));
    await tester.pump();
    expect(shapeController.text, '0');
    await tester.tap(find.widgetWithText(TextButton, '軟便'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '普通便'));
    await tester.pump();
    expect(shapeController.text, '1');
    await tester.tap(find.widgetWithText(TextButton, '普通便'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, '硬便'));
    await tester.pump();
    expect(shapeController.text, '2');

    await tester.tap(find.widgetWithText(TextButton, '多'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'なし'));
    await tester.pump();
    expect(amountController.text, '0');
    expect(shapeController.text, isEmpty);
    expect(find.text('Shape'), findsNothing);
  });

  testWidgets('Activity saves ChoiceChip values into ActivityData', (
    tester,
  ) async {
    final date = DateTime(2026, 7, 25);
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityEntryPage(
          initialData: ActivityData(date: date, measuredSteps: 1000),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final smallChip = find.widgetWithText(ChoiceChip, '少');
    await tester.ensureVisible(smallChip);
    await tester.tap(smallChip);
    await tester.pump();
    final hardChip = find.widgetWithText(ChoiceChip, '硬便');
    await tester.ensureVisible(hardChip);
    await tester.tap(hardChip);
    await tester.pump();
    await tester.ensureVisible(find.text('SAVE ACTIVITY'));
    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pumpAndSettle();

    final saved = await const LocalActivityRepository().findByDate(date);
    expect(saved?.bowelMovement.status, BowelMovementStatus.recorded);
    expect(saved?.bowelMovement.amount, 1);
    expect(saved?.bowelMovement.shape, 3);
  });

  testWidgets('Activity saves the none chip separately from unconfirmed', (
    tester,
  ) async {
    final date = DateTime(2026, 7, 26);
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityEntryPage(
          initialData: ActivityData(date: date, measuredSteps: 1000),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final noneChip = find.widgetWithText(ChoiceChip, 'なし');
    await tester.ensureVisible(noneChip);
    await tester.tap(noneChip);
    await tester.pump();
    await tester.ensureVisible(find.text('SAVE ACTIVITY'));
    await tester.tap(find.text('SAVE ACTIVITY'));
    await tester.pumpAndSettle();

    final saved = await const LocalActivityRepository().findByDate(date);
    expect(saved?.bowelMovement.status, BowelMovementStatus.none);
    expect(saved?.bowelMovement.hasMovement, isFalse);
  });

  testWidgets('editing Activity restores the existing chip selections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityEntryPage(
          initialData: ActivityData(
            date: DateTime(2026, 7, 25),
            measuredSteps: 1000,
            bowelMovement: BowelMovementRecord.recorded(amount: 3, shape: 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '多'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '硬便'), findsOneWidget);
  });

  testWidgets('legacy Morning bowel values appear in Activity chips', (
    tester,
  ) async {
    final date = DateTime(2026, 7, 25);
    final morning = MorningData(
      date: date.toIso8601String(),
      weight: 72.5,
      bodyFat: 18,
      sleepHours: 7.5,
      sleepScore: 80,
      footPain: 2,
      bowelAmount: 2,
      bowelShape: 1,
      workType: WorkType.holiday,
      workStart: '',
      workEnd: '',
      workBreak: '',
      workHours: 0,
      memo: '',
    );
    SharedPreferences.setMockInitialValues({
      'morning_records': [jsonEncode(morning.toJson())],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityEntryPage(
          initialData: ActivityData(date: date, measuredSteps: 1000),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '普通'),
    );
    final shapeChip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '普通便'),
    );
    expect(amountChip.selected, isTrue);
    expect(shapeChip.selected, isTrue);
  });

  testWidgets('step buttons precede Bowel and Morning has no bowel input', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityEntryPage(
          initialData: ActivityData(
            date: DateTime(2026, 7, 25),
            measuredSteps: 1000,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final elements = tester.allElements.toList();
    final officialIndex = elements.indexOf(
      find.text('Official steps').evaluate().single,
    );
    final quickButtonIndex = elements.indexOf(
      find.text('+500').evaluate().single,
    );
    final bowelIndex = elements.indexOf(find.text('BOWEL').evaluate().single);
    expect(officialIndex, lessThan(quickButtonIndex));
    expect(quickButtonIndex, lessThan(bowelIndex));
    expect(find.byType(OperationButton), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: MorningFactPage()));
    await tester.pump();
    expect(find.text('BOWEL'), findsNothing);
    expect(find.byType(BowelCard), findsNothing);
  });

  test('unconfirmed and no bowel movement remain distinct internally', () {
    const unconfirmed = BowelMovementRecord.unconfirmed();
    const none = BowelMovementRecord.none();

    expect(unconfirmed.status, BowelMovementStatus.unconfirmed);
    expect(unconfirmed.hasMovement, isNull);
    expect(none.status, BowelMovementStatus.none);
    expect(none.hasMovement, isFalse);
  });
}
