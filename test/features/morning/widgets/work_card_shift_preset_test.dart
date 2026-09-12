import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/shift_preset.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/services/shift_preset_preferences.dart';
import 'package:or_app/features/morning/widgets/work_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dynamic preset tap applies stored start end and break values', (
    tester,
  ) async {
    await ShiftPresetPreferences.save([
      const ShiftPreset(
        id: 'open',
        name: 'OPEN',
        startTime: '08:00',
        endTime: '17:00',
        breakTime: '01:00',
        order: 0,
      ),
    ]);
    final start = TextEditingController(text: '07:00');
    final end = TextEditingController(text: '18:00');
    final workBreak = TextEditingController(text: '01:00');
    addTearDown(start.dispose);
    addTearDown(end.dispose);
    addTearDown(workBreak.dispose);

    await _pump(tester, start: start, end: end, workBreak: workBreak);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'OPEN'));
    await tester.pump();

    expect(start.text, '08:00');
    expect(end.text, '17:00');
    expect(workBreak.text, '01:00');
  });

  testWidgets(
    'settings edit does not apply until the dynamic button is tapped',
    (tester) async {
      final start = TextEditingController(text: '07:00');
      final end = TextEditingController(text: '18:00');
      final workBreak = TextEditingController(text: '01:00');
      addTearDown(start.dispose);
      addTearDown(end.dispose);
      addTearDown(workBreak.dispose);

      await _pump(
        tester,
        start: start,
        end: end,
        workBreak: workBreak,
        width: 390,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('EDIT SHIFT PRESETS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('早番').last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), '08:00');
      await tester.enterText(fields.at(2), '17:00');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(start.text, '07:00');
      expect(end.text, '18:00');
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '早番'));
      await tester.pump();
      expect(start.text, '08:00');
      expect(end.text, '17:00');
    },
  );

  testWidgets('settings adds a fourth preset and supports zero preset state', (
    tester,
  ) async {
    final start = TextEditingController();
    final end = TextEditingController();
    final workBreak = TextEditingController();
    addTearDown(start.dispose);
    addTearDown(end.dispose);
    addTearDown(workBreak.dispose);

    await _pump(
      tester,
      start: start,
      end: end,
      workBreak: workBreak,
      width: 320,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('EDIT SHIFT PRESETS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'NIGHT');
    await tester.enterText(fields.at(1), '22:00');
    await tester.enterText(fields.at(2), '06:00');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('NIGHT'), findsWidgets);
    expect(find.text('追加'), findsNothing);

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.byTooltip('DELETE PRESET').first);
      await tester.pumpAndSettle();
    }
    expect(find.text('追加'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reorder persists normalized order and updates shift buttons', (
    tester,
  ) async {
    await ShiftPresetPreferences.save([
      ...ShiftPresetPreferences.defaults,
      const ShiftPreset(
        id: 'shift_morning',
        name: '朝番',
        startTime: '09:00',
        endTime: '18:00',
        breakTime: '01:00',
        order: 3,
      ),
    ]);
    final start = TextEditingController();
    final end = TextEditingController();
    final workBreak = TextEditingController();
    addTearDown(start.dispose);
    addTearDown(end.dispose);
    addTearDown(workBreak.dispose);

    await _pump(tester, start: start, end: end, workBreak: workBreak);
    await tester.pumpAndSettle();
    expect(_shiftChipNames(tester), ['早番', '中番', '遅番', '朝番']);

    await tester.tap(find.byTooltip('EDIT SHIFT PRESETS'));
    await tester.pumpAndSettle();
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(4));
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(3, 0);
    await tester.pumpAndSettle();

    expect((await ShiftPresetPreferences.load()).map((preset) => preset.id), [
      'shift_morning',
      'shift_early',
      'shift_middle',
      'shift_late',
    ]);
    expect(
      (await ShiftPresetPreferences.load()).map((preset) => preset.order),
      [0, 1, 2, 3],
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(_shiftChipNames(tester), ['朝番', '早番', '中番', '遅番']);

    await tester.tap(find.byTooltip('EDIT SHIFT PRESETS'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('DELETE PRESET').first);
    await tester.pumpAndSettle();
    expect((await ShiftPresetPreferences.load()).map((preset) => preset.id), [
      'shift_early',
      'shift_middle',
      'shift_late',
    ]);
    expect(
      (await ShiftPresetPreferences.load()).map((preset) => preset.order),
      [0, 1, 2],
    );
  });

  testWidgets('renders one horizontal preset row at mobile and wider widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 900.0]) {
      for (var count = 1; count <= 4; count++) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await ShiftPresetPreferences.save(_presetsForCount(count));
        final start = TextEditingController();
        final end = TextEditingController();
        final workBreak = TextEditingController();
        await _pump(
          tester,
          start: start,
          end: end,
          workBreak: workBreak,
          width: width,
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('EDIT SHIFT PRESETS'), findsOneWidget);
        final chips = _shiftChips(tester);
        expect(chips, hasLength(count));
        expect(
          chips.map((chip) => tester.getTopLeft(chip).dy).toSet(),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        start.dispose();
        end.dispose();
        workBreak.dispose();
      }
    }
  });
}

List<Finder> _shiftChips(WidgetTester tester) {
  return [
    for (final name in _shiftChipNames(tester))
      find.widgetWithText(ChoiceChip, name),
  ];
}

List<String> _shiftChipNames(WidgetTester tester) {
  return tester
      .widgetList<ChoiceChip>(find.byType(ChoiceChip))
      .map((chip) => chip.label)
      .whereType<Text>()
      .map((label) => label.data)
      .whereType<String>()
      .toList();
}

List<ShiftPreset> _presetsForCount(int count) {
  const fourthPreset = ShiftPreset(
    id: 'shift_morning',
    name: '朝番',
    startTime: '09:00',
    endTime: '18:00',
    breakTime: '01:00',
    order: 3,
  );
  return [
    ...ShiftPresetPreferences.defaults,
    fourthPreset,
  ].take(count).toList();
}

Future<void> _pump(
  WidgetTester tester, {
  required TextEditingController start,
  required TextEditingController end,
  required TextEditingController workBreak,
  double width = 900,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorkCard(
            workType: WorkType.work,
            onChanged: (_) {},
            startController: start,
            endController: end,
            breakController: workBreak,
          ),
        ),
      ),
    ),
  );
}
