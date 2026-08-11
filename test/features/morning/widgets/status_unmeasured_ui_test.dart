import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/widgets/inputs/hud/hud_input_card.dart';
import 'package:or_app/core/widgets/inputs/time/operation_time_picker.dart';
import 'package:or_app/core/widgets/inputs/time/time_input_card.dart';
import 'package:or_app/core/widgets/inputs/wheel/wheel_input_card.dart';
import 'package:or_app/features/morning/widgets/body_card.dart';
import 'package:or_app/features/morning/widgets/recovery_card.dart';
import 'package:or_app/features/morning/services/morning_submit_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('task102 close: Weight unmeasured also hides Body Fat', (
    tester,
  ) async {
    final weight = TextEditingController(text: '100.0');
    final bodyFat = TextEditingController(text: '20.0');
    var weightUnmeasured = false;

    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BodyCard(
          weightController: weight,
          bodyFatController: bodyFat,
          weightUnmeasured: weightUnmeasured,
          onWeightUnmeasured: () => setState(() {
            weight.clear();
            bodyFat.clear();
            weightUnmeasured = true;
          }),
          onWeightMeasured: () => setState(() => weightUnmeasured = false),
        ),
      ),
      width: 390,
    );

    _expectSectionToggle(
      tester,
      title: 'BODY',
      actionKey: const ValueKey('Weight-unmeasured-toggle'),
      input: find.byType(HUDInputCard),
      selected: false,
    );
    expect(
      find.byKey(const ValueKey('Body Fat-unmeasured-toggle')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('Weight-unmeasured-toggle')));
    await tester.pump();
    expect(find.byType(HUDInputCard), findsNothing);
    expect(find.byType(WheelInputCard), findsNothing);
    expect(weight.text, isEmpty);
    expect(bodyFat.text, isEmpty);
    _expectUnmeasuredValueStyle(tester, 'Weight');
    expect(find.text('未計測'), findsNWidgets(3));
    expect(
      _choiceChip(tester, const ValueKey('Weight-unmeasured-toggle')).selected,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('Body Fat-unmeasured-toggle')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('Weight-unmeasured-toggle')));
    await tester.pump();
    expect(find.byType(HUDInputCard), findsOneWidget);
    expect(find.byType(WheelInputCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('Body Fat-unmeasured-toggle')),
      findsNothing,
    );
  });

  testWidgets('task103: Body Fat has no independent unmeasured action', (
    tester,
  ) async {
    final weight = TextEditingController(text: '100.0');
    final bodyFat = TextEditingController(text: '20.0');

    await _pump(
      tester,
      BodyCard(
        weightController: weight,
        bodyFatController: bodyFat,
        weightUnmeasured: false,
        onWeightUnmeasured: () {},
        onWeightMeasured: () {},
      ),
      width: 390,
    );

    expect(find.byType(HUDInputCard), findsOneWidget);
    expect(find.byType(WheelInputCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('Body Fat-unmeasured-toggle')),
      findsNothing,
    );
  });

  test('task102 close: Weight null always saves Body Fat as null', () async {
    final error = await MorningSubmitService.submit(
      workType: WorkType.holiday,
      weightText: '',
      bodyFatText: '20.0',
      sleepText: '8:00',
      sleepScoreText: '80',
      sleepType: SleepType.sleep,
      footPainText: '0',
      workStart: '',
      workEnd: '',
      workBreak: '',
      memo: '',
      operationLocalDate: '2026-08-11',
    );

    expect(error, isNull);
    final saved = (await MorningRepository.getAll()).single;
    expect(saved.weight, isNull);
    expect(saved.bodyFat, isNull);
  });

  testWidgets('task091 recovery hotfix: Sleep Time unmeasured hides both', (
    tester,
  ) async {
    final sleepTime = TextEditingController(text: '8:00');
    final sleepScore = TextEditingController(text: '80');
    var timeUnmeasured = false;

    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => RecoveryCard(
          sleepController: sleepTime,
          sleepScoreController: sleepScore,
          sleepType: SleepType.sleep,
          onSleepTypeChanged: (_) {},
          sleepTimeUnmeasured: timeUnmeasured,
          onSleepTimeUnmeasured: () => setState(() {
            sleepTime.clear();
            sleepScore.clear();
            timeUnmeasured = true;
          }),
          onSleepTimeMeasured: () => setState(() => timeUnmeasured = false),
        ),
      ),
      width: 390,
    );

    _expectSectionToggle(
      tester,
      title: 'RECOVERY',
      actionKey: const ValueKey('Sleep Time-unmeasured-toggle'),
      input: find.byType(TimeInputCard),
      selected: false,
    );

    await tester.tap(
      find.byKey(const ValueKey('Sleep Time-unmeasured-toggle')),
    );
    await tester.pump();
    expect(find.byType(TimeInputCard), findsNothing);
    expect(find.byType(WheelInputCard), findsNothing);
    expect(find.text('未計測'), findsNWidgets(3));
    expect(
      _choiceChip(
        tester,
        const ValueKey('Sleep Time-unmeasured-toggle'),
      ).selected,
      isTrue,
    );
    expect(
      find.byKey(const ValueKey('Sleep Score-unmeasured-toggle')),
      findsNothing,
    );
    expect(sleepTime.text, isEmpty);
    expect(sleepScore.text, isEmpty);
    _expectUnmeasuredValueStyle(tester, 'Sleep Time');
  });

  testWidgets(
    'task091 recovery hotfix: Sleep Time measured restores sleep score input',
    (tester) async {
      final sleepTime = TextEditingController();
      final sleepScore = TextEditingController();
      var timeUnmeasured = true;

      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => RecoveryCard(
            sleepController: sleepTime,
            sleepScoreController: sleepScore,
            sleepType: SleepType.sleep,
            onSleepTypeChanged: (_) {},
            sleepTimeUnmeasured: timeUnmeasured,
            onSleepTimeUnmeasured: () {},
            onSleepTimeMeasured: () => setState(() => timeUnmeasured = false),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('Sleep Time-unmeasured-toggle')),
      );
      await tester.pump();
      expect(find.byType(TimeInputCard), findsOneWidget);
      expect(find.byType(WheelInputCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('Sleep Score-unmeasured-toggle')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'task091 recovery hotfix: Sleep Time measured preserves nap score UI',
    (tester) async {
      final sleepTime = TextEditingController();
      final sleepScore = TextEditingController();
      var timeUnmeasured = true;

      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => RecoveryCard(
            sleepController: sleepTime,
            sleepScoreController: sleepScore,
            sleepType: SleepType.nap,
            onSleepTypeChanged: (_) {},
            sleepTimeUnmeasured: timeUnmeasured,
            onSleepTimeUnmeasured: () {},
            onSleepTimeMeasured: () => setState(() => timeUnmeasured = false),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('Sleep Time-unmeasured-toggle')),
      );
      await tester.pump();
      expect(find.byType(TimeInputCard), findsOneWidget);
      expect(find.byType(WheelInputCard), findsNothing);
      expect(find.text('仮眠'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('Sleep Score-unmeasured-toggle')),
        findsNothing,
      );
    },
  );

  testWidgets('task091 hotfix: time ruler style follows current selection', (
    tester,
  ) async {
    final controller = TextEditingController(text: '8:00');
    await _pump(
      tester,
      OperationTimePicker(controller: controller, minuteStep: 1),
    );

    controller.text = '8:10';
    await tester.pump();

    expect(_hasSelectedText(tester, '08'), isTrue);
    expect(_hasSelectedText(tester, '10'), isTrue);
    expect(_hasSelectedText(tester, '00'), isFalse);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 900,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void _expectSectionToggle(
  WidgetTester tester, {
  required String title,
  required ValueKey<String> actionKey,
  required Finder input,
  required bool selected,
}) {
  final action = find.byKey(actionKey);
  final actionRect = tester.getRect(action);
  final inputRect = tester.getRect(input);
  final titleRect = tester.getRect(find.text(title));

  expect(find.descendant(of: input, matching: action), findsNothing);
  expect(actionRect.right, closeTo(inputRect.right, 0.1));
  expect(actionRect.bottom, lessThan(inputRect.top));
  expect(actionRect.center.dy, closeTo(titleRect.center.dy, 8));
  expect(_choiceChip(tester, actionKey).selected, selected);
}

ChoiceChip _choiceChip(WidgetTester tester, ValueKey<String> actionKey) =>
    tester.widget<ChoiceChip>(
      find.descendant(
        of: find.byKey(actionKey),
        matching: find.byType(ChoiceChip),
      ),
    );

void _expectUnmeasuredValueStyle(WidgetTester tester, String title) {
  final valueRow = find
      .ancestor(of: find.text(title), matching: find.byType(Row))
      .first;
  final text = tester.widget<Text>(
    find.descendant(of: valueRow, matching: find.text('未計測')),
  );
  expect(text.style?.fontSize, 20);
  expect(text.style?.fontWeight, FontWeight.w600);
  expect(text.style?.color, Colors.lightBlueAccent);
}

bool _hasSelectedText(WidgetTester tester, String value) => tester
    .widgetList<Text>(find.text(value))
    .any(
      (text) =>
          text.style?.fontSize == 28 &&
          text.style?.fontWeight == FontWeight.bold &&
          text.style?.color == Colors.white,
    );
