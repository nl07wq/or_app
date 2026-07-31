import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/theme/app_spacing.dart';
import 'package:or_app/features/morning/services/morning_submit_service.dart';
import 'package:or_app/features/morning/widgets/foot_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../operation_date/operation_date_test_fixture.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts expanded when no pain level has been entered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));

    expect(find.byKey(const Key('foot-pain-current-value')), findsNothing);
    expect(
      find.byKey(const Key('foot-pain-current-value-button')),
      findsNothing,
    );

    final firstRow = find.byKey(const Key('foot-pain-levels-1-5'));
    final secondRow = find.byKey(const Key('foot-pain-levels-6-10'));
    expect(tester.widget(firstRow), isA<LayoutBuilder>());
    expect(tester.widget(secondRow), isA<LayoutBuilder>());
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);

    await tester.tap(find.text('Pain Level'));
    await tester.pump();
    expect(find.byKey(const Key('foot-pain-chip-1')), findsOneWidget);

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

    final compactSizes = [
      for (var value = 1; value <= 10; value++)
        tester.getSize(find.byKey(Key('foot-pain-chip-$value'))),
    ];
    expect(compactSizes.map((size) => size.width).toSet(), hasLength(1));
    expect(compactSizes.first.width, closeTo(49.2, 0.01));
    expect(compactSizes.first.height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the selected value expands the choices', (tester) async {
    final controller = TextEditingController(text: '3');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(_currentValue(tester), '3');
    expect(find.byKey(const Key('foot-pain-chip-3')), findsNothing);

    await tester.tap(find.text('Pain Level'));
    await tester.pump();
    expect(find.byKey(const Key('foot-pain-chip-3')), findsNothing);

    await _tapCurrentValue(tester);
    expect(find.byKey(const Key('foot-pain-chip-3')), findsOneWidget);

    await tester.tap(find.text('Pain Level'));
    await tester.pump();
    expect(find.byKey(const Key('foot-pain-chip-3')), findsOneWidget);
  });

  testWidgets('collapsed value matches the Sleep Score accent style', (
    tester,
  ) async {
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    final currentValue = tester.widget<Text>(
      find.byKey(const Key('foot-pain-current-value')),
    );
    expect(currentValue.data, '5');
    expect(currentValue.style?.fontSize, 20);
    expect(currentValue.style?.fontWeight, FontWeight.w600);
    expect(currentValue.style?.color, Colors.lightBlueAccent);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
  });

  testWidgets('PWA width distributes five chips across the full row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));
    await _tapCurrentValue(tester);

    final firstRow = find.byKey(const Key('foot-pain-levels-1-5'));
    final firstRowRect = tester.getRect(firstRow);
    final chipRects = [
      for (var value = 1; value <= 5; value++)
        tester.getRect(find.byKey(Key('foot-pain-chip-$value'))),
    ];
    final centerSpacing = firstRowRect.width / 5;

    expect(
      find.descendant(of: firstRow, matching: find.byType(Expanded)),
      findsNWidgets(5),
    );
    for (var index = 1; index < chipRects.length; index++) {
      expect(
        chipRects[index].center.dx - chipRects[index - 1].center.dx,
        closeTo(centerSpacing, 0.01),
      );
    }
    expect(chipRects.first.left - firstRowRect.left, closeTo(4, 0.01));
    expect(firstRowRect.right - chipRects.last.right, closeTo(4, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop width keeps two fixed rows left aligned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TextEditingController(text: '10');
    addTearDown(controller.dispose);

    await tester.pumpWidget(_testApp(controller));
    await _tapCurrentValue(tester);

    final firstRow = find.byKey(const Key('foot-pain-levels-1-5'));
    final firstRowRect = tester.getRect(firstRow);
    final firstChipRect = tester.getRect(
      find.byKey(const Key('foot-pain-chip-1')),
    );
    final sizes = [
      for (var value = 1; value <= 10; value++)
        tester.getSize(find.byKey(Key('foot-pain-chip-$value'))),
    ];

    expect(sizes.every((size) => size == const Size(72, 48)), isTrue);
    expect(firstChipRect.left, firstRowRect.left);
    expect(
      find.descendant(of: firstRow, matching: find.byType(Expanded)),
      findsNothing,
    );
    expect(_checkmarkFinder(10), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection updates the value and automatically collapses', (
    tester,
  ) async {
    final controller = TextEditingController(text: '3');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await _tapCurrentValue(tester);

    final chipFinder = find.byKey(const Key('foot-pain-chip-8'));
    final labelFinder = find.descendant(
      of: chipFinder,
      matching: find.text('8'),
    );
    final beforeSize = tester.getSize(chipFinder);
    final chipCenter = tester.getCenter(chipFinder).dx;
    final beforeLabelCenter = tester.getCenter(labelFinder).dx;
    expect((beforeLabelCenter - chipCenter).abs(), lessThan(1));
    expect(_checkmarkFinder(8), findsNothing);

    await tester.tap(chipFinder);
    await tester.pumpAndSettle();

    expect(controller.text, '8');
    expect(_currentValue(tester), '8');
    expect(chipFinder, findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);

    await _tapCurrentValue(tester);
    expect(_checkmarkFinder(8), findsOneWidget);
    expect(tester.getSize(chipFinder), beforeSize);
    expect(tester.getCenter(labelFinder).dx, greaterThan(beforeLabelCenter));
  });

  testWidgets('uses themed Material, ripple, and rounded geometry', (
    tester,
  ) async {
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await _tapCurrentValue(tester);

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
    expect(inkWell.onTap, isNotNull);
    expect(inkWell.customBorder, shape);
  });

  testWidgets('exposes button, selection, label, and tap semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: '4');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));
    await _tapCurrentValue(tester);

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

  testWidgets('supports keyboard expansion and selection', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.text, '1');
    expect(_currentValue(tester), '1');
    expect(find.byKey(const Key('foot-pain-chip-1')), findsNothing);
  });

  testWidgets('external controller updates refresh the current value', (
    tester,
  ) async {
    final controller = TextEditingController(text: '2');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(_currentValue(tester), '2');
    controller.text = '9';
    await tester.pump();
    expect(_currentValue(tester), '9');

    await _tapCurrentValue(tester);
    expect(_checkmarkFinder(2), findsNothing);
    expect(_checkmarkFinder(9), findsOneWidget);
  });

  testWidgets('clearing an external value forces the choices to stay open', (
    tester,
  ) async {
    final controller = TextEditingController(text: '2');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    controller.clear();
    await tester.pump();

    expect(find.byKey(const Key('foot-pain-current-value')), findsNothing);
    expect(find.byKey(const Key('foot-pain-chip-2')), findsOneWidget);

    await tester.tap(find.text('Pain Level'));
    await tester.pump();
    expect(find.byKey(const Key('foot-pain-chip-2')), findsOneWidget);
  });

  testWidgets('legacy value 0 displays unselected without changing storage', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(controller.text, '0');
    expect(find.byKey(const Key('foot-pain-current-value')), findsNothing);
    expect(
      find.byKey(const Key('foot-pain-current-value-button')),
      findsNothing,
    );
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
      operationDateService: await operationDateServiceFor('2026-07-31'),
    );

    expect(error, isNull);
    final saved = (await MorningRepository.getAll()).single;
    expect(saved.footPain, 7);
  });

  testWidgets('guidance is visible only while expanded', (tester) async {
    final controller = TextEditingController(text: '3');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_testApp(controller));

    expect(find.textContaining('1–2：軽微'), findsNothing);
    await _tapCurrentValue(tester);

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

Future<void> _tapCurrentValue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('foot-pain-current-value-button')));
  await tester.pump();
}

String? _currentValue(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('foot-pain-current-value')))
      .data;
}

Finder _checkmarkFinder(int value) {
  return find.descendant(
    of: find.byKey(Key('foot-pain-chip-$value')),
    matching: find.byIcon(Icons.check),
  );
}
