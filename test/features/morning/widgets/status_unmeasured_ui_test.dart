import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/models/work_type.dart';
import 'package:or_app/core/repositories/morning_repository.dart';
import 'package:or_app/core/widgets/inputs/hud/hud_ruler.dart';
import 'package:or_app/core/widgets/inputs/operation_ruler.dart';
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
      input: find.byKey(const ValueKey('status-weight-hud')),
      selected: false,
    );
    expect(
      find.byKey(const ValueKey('Body Fat-unmeasured-toggle')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('Weight-unmeasured-toggle')));
    await tester.pump();
    expect(find.byKey(const ValueKey('status-weight-hud')), findsNothing);
    expect(find.byKey(const ValueKey('status-body-fat-ring')), findsNothing);
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
    expect(find.byKey(const ValueKey('status-weight-hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-body-fat-ring')), findsOneWidget);
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

    expect(find.byKey(const ValueKey('status-weight-hud')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-body-fat-ring')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('Body Fat-unmeasured-toggle')),
      findsNothing,
    );
  });

  testWidgets('new STATUS draft keeps seeded BODY and RECOVERY inputs open', (
    tester,
  ) async {
    final weight = TextEditingController(text: '72.4');
    final bodyFat = TextEditingController(text: '18.6');
    final sleep = TextEditingController(text: '7:05');
    final score = TextEditingController(text: '82');
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    addTearDown(sleep.dispose);
    addTearDown(score.dispose);
    await _pump(
      tester,
      Column(
        children: [
          BodyCard(
            weightController: weight,
            bodyFatController: bodyFat,
            weightUnmeasured: false,
            onWeightUnmeasured: () {},
            onWeightMeasured: () {},
            initiallyExpanded: true,
          ),
          RecoveryCard(
            sleepController: sleep,
            sleepScoreController: score,
            sleepType: SleepType.sleep,
            onSleepTypeChanged: (_) {},
            sleepTimeUnmeasured: false,
            onSleepTimeUnmeasured: () {},
            onSleepTimeMeasured: () {},
            initiallyExpanded: true,
          ),
        ],
      ),
      width: 390,
    );

    expect(find.byKey(const ValueKey('status-weight-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-body-fat-done')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('status-sleep-score-done')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('status-sleep-duration-picker')),
      findsOneWidget,
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
      input: find.byKey(const ValueKey('status-sleep-duration-picker')),
      selected: false,
      alignRight: false,
    );

    await tester.tap(
      find.byKey(const ValueKey('Sleep Time-unmeasured-toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('status-sleep-duration-picker')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('status-sleep-score-hud-sleep')),
      findsNothing,
    );
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
      expect(
        find.byKey(const ValueKey('status-sleep-duration-picker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-sleep-score-hud-sleep')),
        findsOneWidget,
      );
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
      expect(
        find.byKey(const ValueKey('status-sleep-duration-picker')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('status-sleep-score-hud-nap')),
        findsNothing,
      );
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
    final controller = TextEditingController(text: '80');
    await _pump(
      tester,
      OperationRuler(
        controller: controller,
        min: 0,
        max: 100,
        step: 1,
        unit: '',
        initialValue: 80,
      ),
    );

    controller.text = '90';
    await tester.pump();

    expect(controller.text, '90');
    expect(tester.takeException(), isNull);
  });

  testWidgets('HUD ruler changes a value with a horizontal drag', (
    tester,
  ) async {
    final controller = TextEditingController(text: '80');
    await _pump(
      tester,
      OperationRuler(
        controller: controller,
        min: 0,
        max: 100,
        step: 1,
        unit: '',
        initialValue: 80,
      ),
    );

    final dragSurface = find.descendant(
      of: find.byType(HUDRuler),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector && widget.onHorizontalDragUpdate != null,
      ),
    );
    await tester.drag(dragSurface, const Offset(144, 0));
    await tester.pump(const Duration(milliseconds: 400));

    expect(double.parse(controller.text), lessThan(80));
  });

  testWidgets('status HUD inputs fit the supported iPhone widths', (
    tester,
  ) async {
    for (final width in <double>[320, 375, 390, 430]) {
      await _pump(
        tester,
        Column(
          children: [
            BodyCard(
              weightController: TextEditingController(text: '72.4'),
              bodyFatController: TextEditingController(text: '18.6'),
              weightUnmeasured: false,
              onWeightUnmeasured: () {},
              onWeightMeasured: () {},
            ),
            RecoveryCard(
              sleepController: TextEditingController(text: '7:05'),
              sleepScoreController: TextEditingController(text: '82'),
              sleepType: SleepType.sleep,
              onSleepTypeChanged: (_) {},
              sleepTimeUnmeasured: false,
              onSleepTimeUnmeasured: () {},
              onSleepTimeMeasured: () {},
            ),
          ],
        ),
        width: width,
      );

      expect(find.byKey(const ValueKey('status-weight-hud')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-sleep-duration-picker')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('sleep duration opens the shared orbital duration mode', (
    tester,
  ) async {
    final sleepTime = TextEditingController(text: '7:05');
    await _pump(
      tester,
      RecoveryCard(
        sleepController: sleepTime,
        sleepScoreController: TextEditingController(text: '82'),
        sleepType: SleepType.sleep,
        onSleepTypeChanged: (_) {},
        sleepTimeUnmeasured: false,
        onSleepTimeUnmeasured: () {},
        onSleepTimeMeasured: () {},
      ),
      width: 390,
    );

    await tester.tap(
      find.byKey(const ValueKey('status-sleep-duration-picker')),
    );
    await tester.pumpAndSettle();

    expect(find.text('DURATION HOUR'), findsOneWidget);
    expect(find.text('AM'), findsNothing);
    expect(find.text('PM'), findsNothing);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(sleepTime.text, '7:05');
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
  bool alignRight = true,
}) {
  final action = find.byKey(actionKey);
  final actionRect = tester.getRect(action);
  final inputRect = tester.getRect(input);
  final titleRect = tester.getRect(find.text(title));

  expect(find.descendant(of: input, matching: action), findsNothing);
  if (alignRight) {
    expect(actionRect.right, closeTo(inputRect.right, 0.1));
  }
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
