import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/theme/app_spacing.dart';
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
    expect(tester.widget(firstRow), isA<LayoutBuilder>());
    expect(tester.widget(secondRow), isA<LayoutBuilder>());
    expect(find.byType(ChoiceChip), findsNothing);

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
    for (var value = 1; value <= 10; value++) {
      expect(_checkmarkFinder(value), findsNothing);
    }

    final compactSizes = [
      for (var value = 1; value <= 10; value++)
        tester.getSize(find.byKey(Key('foot-pain-chip-$value'))),
    ];
    expect(compactSizes.map((size) => size.width).toSet(), hasLength(1));
    expect(compactSizes.first, const Size(50, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a fixed slightly-wide shape without flex sizing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));

    final firstRow = find.byKey(const Key('foot-pain-levels-1-5'));
    final sizes = [
      for (var value = 1; value <= 10; value++)
        tester.getSize(find.byKey(Key('foot-pain-chip-$value'))),
    ];

    expect(sizes.map((size) => size.width).toSet(), hasLength(1));
    expect(sizes.every((size) => size == const Size(56, 48)), isTrue);
    expect(sizes.first.width, greaterThan(sizes.first.height));
    expect(
      find.descendant(of: firstRow, matching: find.byType(Expanded)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byType(FractionallySizedBox),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the final fixed size at desktop width', (tester) async {
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
    expect(sizes.every((size) => size == const Size(56, 48)), isTrue);
    expect(_checkmarkFinder(10), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses themed Material, ripple, and rounded geometry', (
    tester,
  ) async {
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    final material = tester.widget<Material>(
      find.byKey(const Key('foot-pain-material-5')),
    );
    final inkWell = tester.widget<InkWell>(
      find.byKey(const Key('foot-pain-inkwell-5')),
    );
    final shape = material.shape! as RoundedRectangleBorder;
    final colorScheme = Theme.of(
      tester.element(find.byKey(const Key('foot-pain-chip-5'))),
    ).colorScheme;

    expect(material.color, colorScheme.secondaryContainer);
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(8)));
    expect(
      tester.getSize(find.byKey(const Key('foot-pain-chip-5'))),
      const Size(56, 48),
    );
    expect(inkWell.onTap, isNotNull);
    expect(inkWell.customBorder, shape);
  });

  testWidgets('selection adds only the check and keeps the outer size fixed', (
    tester,
  ) async {
    final controller = TextEditingController(text: '3');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    final chipFinder = find.byKey(const Key('foot-pain-chip-8'));
    final labelFinder = find.descendant(
      of: chipFinder,
      matching: find.text('8'),
    );
    final materialFinder = find.byKey(const Key('foot-pain-material-8'));
    final beforeSize = tester.getSize(chipFinder);
    final beforeMaterialSize = tester.getSize(materialFinder);
    final chipCenter = tester.getCenter(chipFinder).dx;
    final beforeLabelCenter = tester.getCenter(labelFinder).dx;
    expect((beforeLabelCenter - chipCenter).abs(), lessThan(1));
    expect(_checkmarkFinder(8), findsNothing);

    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

    final afterLabelCenter = tester.getCenter(labelFinder).dx;
    expect(controller.text, '8');
    expect(_checkmarkFinder(3), findsNothing);
    expect(_checkmarkFinder(8), findsOneWidget);
    expect(afterLabelCenter, greaterThan(beforeLabelCenter));
    expect(tester.getSize(chipFinder), beforeSize);
    expect(tester.getSize(materialFinder), beforeMaterialSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes button, selection, label, and tap semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: '4');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(
      tester.getSemantics(find.byKey(const Key('foot-pain-chip-4'))),
      matchesSemantics(
        label: 'Pain level 4',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('supports keyboard activation through InkWell', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, '1');
    expect(_checkmarkFinder(1), findsOneWidget);
  });

  testWidgets('external controller updates refresh the selected chip', (
    tester,
  ) async {
    final controller = TextEditingController(text: '2');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    controller.text = '9';
    await tester.pump();

    expect(_checkmarkFinder(2), findsNothing);
    expect(_checkmarkFinder(9), findsOneWidget);
  });

  testWidgets('legacy value 0 remains stored and selects no chip', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(controller.text, '0');
    for (var value = 1; value <= 10; value++) {
      expect(_checkmarkFinder(value), findsNothing);
    }
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

Finder _checkmarkFinder(int value) {
  return find.descendant(
    of: find.byKey(Key('foot-pain-chip-$value')),
    matching: find.byIcon(Icons.check),
  );
}
