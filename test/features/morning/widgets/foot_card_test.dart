import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/theme/app_spacing.dart';
import 'package:or_app/features/activity/widgets/bowel_card.dart';
import 'package:or_app/features/morning/services/morning_submit_service.dart';
import 'package:or_app/features/morning/widgets/foot_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows 1 to 10 in two fixed rows with no initial selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));

    final firstRow = find.byKey(const Key('foot-pain-levels-1-5'));
    final secondRow = find.byKey(const Key('foot-pain-levels-6-10'));
    expect(tester.widget(firstRow), isA<Row>());
    expect(tester.widget(secondRow), isA<Row>());
    expect(find.byType(ChoiceChip), findsNWidgets(10));

    for (final value in [1, 2, 3, 4, 5]) {
      expect(
        find.descendant(
          of: firstRow,
          matching: find.byKey(Key('foot-pain-chip-$value')),
        ),
        findsOneWidget,
      );
    }
    for (final value in [6, 7, 8, 9, 10]) {
      expect(
        find.descendant(
          of: secondRow,
          matching: find.byKey(Key('foot-pain-chip-$value')),
        ),
        findsOneWidget,
      );
    }

    expect(controller.text, isEmpty);
    expect(
      [
        for (var value = 1; value <= 10; value++) _chip(tester, value),
      ].every((chip) => !chip.selected),
      isTrue,
    );
    final compactSizes = [
      for (var value = 1; value <= 10; value++)
        tester.getSize(find.byKey(Key('foot-pain-chip-$value'))),
    ];
    expect(compactSizes.map((size) => size.width).toSet(), hasLength(1));
    expect(compactSizes.every((size) => size.height == 48), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Bowel height while preserving equal five-chip rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));

    final sizes = [
      for (var value = 1; value <= 10; value++)
        tester.getSize(find.byKey(Key('foot-pain-chip-$value'))),
    ];
    expect(sizes.map((size) => size.width).toSet(), hasLength(1));
    expect(sizes.every((size) => size.height == 48), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps fixed Bowel height at desktop width', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '10');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));

    final sizes = [
      for (var value = 1; value <= 10; value++)
        tester.getSize(find.byKey(Key('foot-pain-chip-$value'))),
    ];
    expect(sizes.map((size) => size.width).toSet(), hasLength(1));
    expect(sizes.every((size) => size.height == 48), isTrue);
    expect(_chip(tester, 10).selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the same visual configuration as Bowel ChoiceChip', (
    tester,
  ) async {
    final footController = TextEditingController();
    final amountController = TextEditingController();
    final shapeController = TextEditingController();
    addTearDown(footController.dispose);
    addTearDown(amountController.dispose);
    addTearDown(shapeController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          children: [
            BowelCard(
              amountController: amountController,
              shapeController: shapeController,
            ),
            FootCard(controller: footController),
          ],
        ),
      ),
    );

    final bowelChipFinder = find.widgetWithText(ChoiceChip, '少');
    final bowelChip = tester.widget<ChoiceChip>(bowelChipFinder);
    final footChip = _chip(tester, 1);

    expect(
      tester.getSize(find.byKey(const Key('foot-pain-chip-1'))).height,
      tester.getSize(bowelChipFinder).height,
    );
    expect(footChip.padding, bowelChip.padding);
    expect(footChip.labelPadding, bowelChip.labelPadding);
    expect(footChip.labelStyle, bowelChip.labelStyle);
    expect(footChip.shape, bowelChip.shape);
    expect(footChip.side, bowelChip.side);
    expect(footChip.selectedColor, bowelChip.selectedColor);
    expect(footChip.backgroundColor, bowelChip.backgroundColor);
    expect(footChip.checkmarkColor, bowelChip.checkmarkColor);
    expect(footChip.showCheckmark, bowelChip.showCheckmark);
    expect(footChip.materialTapTargetSize, bowelChip.materialTapTargetSize);
    expect(footChip.visualDensity, bowelChip.visualDensity);
    expect((footChip.avatar as SizedBox).width, 18);
    expect((footChip.avatar as SizedBox).height, 18);
    expect((bowelChip.avatar as Icon).size, 18);
  });

  testWidgets('selecting a chip updates the controller and selection', (
    tester,
  ) async {
    final controller = TextEditingController(text: '3');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    final chipFinder = find.byKey(const Key('foot-pain-chip-8'));
    final beforeSize = tester.getSize(chipFinder);
    final beforeChip = _chip(tester, 8);

    await tester.tap(chipFinder);
    await tester.pump();

    final afterChip = _chip(tester, 8);
    expect(controller.text, '8');
    expect(_chip(tester, 3).selected, isFalse);
    expect(afterChip.selected, isTrue);
    expect(tester.getSize(chipFinder), beforeSize);
    expect(afterChip.padding, beforeChip.padding);
    expect(afterChip.labelPadding, beforeChip.labelPadding);
    expect(afterChip.shape, beforeChip.shape);
    expect(afterChip.side, beforeChip.side);
    expect(tester.takeException(), isNull);
  });

  testWidgets('external controller updates refresh the selected chip', (
    tester,
  ) async {
    final controller = TextEditingController(text: '2');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    controller.text = '9';
    await tester.pump();

    expect(_chip(tester, 2).selected, isFalse);
    expect(_chip(tester, 9).selected, isTrue);
  });

  testWidgets('legacy value 0 remains stored and selects no chip', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(controller.text, '0');
    expect(
      [
        for (var value = 1; value <= 10; value++) _chip(tester, value),
      ].every((chip) => !chip.selected),
      isTrue,
    );
  });

  testWidgets('selected value is saved through the existing submit service', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    await tester.tap(find.byKey(const Key('foot-pain-chip-7')));
    await tester.pump();

    final error = await MorningSubmitService.submit(
      workType: WorkType.holiday,
      weightText: '72.5',
      bodyFatText: '18',
      sleepText: '7:30',
      sleepScoreText: '80',
      footPainText: controller.text,
      workStart: '',
      workEnd: '',
      workBreak: '',
      memo: '',
    );

    expect(error, isNull);
    final saved = (await MorningRepository.getAll()).single;
    expect(saved.footPain, 7);
  });

  testWidgets('shows the pain severity guidance as secondary text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(find.textContaining('1–2：軽微'), findsOneWidget);
    expect(find.textContaining('3–4：軽い'), findsOneWidget);
    expect(find.textContaining('5–6：中程度'), findsOneWidget);
    expect(find.textContaining('7–8：強い'), findsOneWidget);
    expect(find.textContaining('9–10：非常に強い'), findsOneWidget);

    final guidance = tester.widget<Text>(find.textContaining('1–2：軽微'));
    expect(
      guidance.style,
      Theme.of(tester.element(find.byType(FootCard))).textTheme.bodySmall,
    );
  });
}

Widget _testApp(TextEditingController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: AppSpacing.cardPadding,
        child: FootCard(controller: controller),
      ),
    ),
  );
}

ChoiceChip _chip(WidgetTester tester, int value) {
  return tester.widget<ChoiceChip>(find.byKey(Key('foot-pain-chip-$value')));
}
