import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/morning_data.dart';
import 'package:or_app/core/services/device_settings_controller.dart';
import 'package:or_app/features/morning/widgets/body_card.dart';
import 'package:or_app/features/morning/widgets/base_camp_status_style.dart';
import 'package:or_app/features/morning/widgets/foot_card.dart';
import 'package:or_app/features/morning/widgets/recovery_card.dart';
import 'package:or_app/features/themes/base_camp/base_camp_presentation.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_terminal.dart';
import 'package:or_app/features/themes/base_camp/base_camp_retro_theme.dart';

void main() {
  setUp(() {
    DeviceSettingsController.instance.resetForTesting(const DeviceSettings());
  });

  testWidgets('BASE CAMP weight uses fixed-needle radio tuner controls', (
    tester,
  ) async {
    final weight = TextEditingController(text: '94.2');
    final bodyFat = TextEditingController(text: '31.9');
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
        BodyCard(
          weightController: weight,
          bodyFatController: bodyFat,
          weightUnmeasured: false,
          onWeightUnmeasured: () {},
          onWeightMeasured: () {},
          initiallyExpanded: true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('status-weight-radio-scale')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('status-weight-rotary-dial')),
      findsOneWidget,
    );
    expect(find.text('94.2 kg'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('status-weight-lcd-window')),
        matching: find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('status-weight-rotary-dial')),
        matching: find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('status-weight-plus')),
        matching: find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('status-weight-plus')));
    await tester.pump();
    expect(weight.text, '94.3');
    await tester.tap(find.byKey(const ValueKey('status-weight-minus')));
    await tester.pump();
    expect(weight.text, '94.2');

    final scale = find.byKey(const ValueKey('status-weight-radio-scale'));
    await tester.drag(scale, const Offset(-32, 0));
    await tester.pump();
    expect(weight.text, '94.3');

    final dial = tester.getRect(
      find.byKey(const ValueKey('status-weight-rotary-dial')),
    );
    final dialGesture = await tester.startGesture(
      Offset(dial.right - 3, dial.center.dy),
    );
    await dialGesture.moveTo(Offset(dial.center.dx, dial.bottom - 3));
    await dialGesture.up();
    await tester.pump();
    expect(weight.text, '94.9');
    expect(tester.takeException(), isNull);
  });

  testWidgets('BASE CAMP rotary dial crosses zero for repeated revolutions', (
    tester,
  ) async {
    final weight = TextEditingController(text: '94.2');
    final bodyFat = TextEditingController(text: '31.9');
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
        BodyCard(
          weightController: weight,
          bodyFatController: bodyFat,
          weightUnmeasured: false,
          onWeightUnmeasured: () {},
          onWeightMeasured: () {},
          initiallyExpanded: true,
        ),
      ),
    );

    final dial = find.byKey(const ValueKey('status-weight-rotary-dial'));
    await _rotateDial(tester, dial, turns: 2);
    expect(weight.text, '99.0');
    await _rotateDial(tester, dial, turns: -1);
    expect(weight.text, '96.6');
    await _rotateDial(tester, dial, turns: .5);
    await _rotateDial(tester, dial, turns: -.5);
    expect(weight.text, '96.6');
    weight.text = '179.9';
    await tester.pump();
    await _rotateDial(tester, dial, turns: .5);
    expect(weight.text, '180.0');
    weight.text = '40.1';
    await tester.pump();
    await _rotateDial(tester, dial, turns: -.5);
    expect(weight.text, '40.0');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'BASE CAMP body fat uses fixed 0-60 gauge with buttons and touch',
    (tester) async {
      final weight = TextEditingController(text: '94.2');
      final bodyFat = TextEditingController(text: '31.9');
      addTearDown(weight.dispose);
      addTearDown(bodyFat.dispose);
      await tester.pumpWidget(
        _baseCampHarness(
          BodyCard(
            weightController: weight,
            bodyFatController: bodyFat,
            weightUnmeasured: false,
            onWeightUnmeasured: () {},
            onWeightMeasured: () {},
            initiallyExpanded: true,
          ),
        ),
      );

      expect(find.text('31.9 %'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-body-fat-segments')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('status-body-fat-plus')));
      await tester.pump();
      expect(bodyFat.text, '32.0');
      expect(find.text('0.0%'), findsOneWidget);
      expect(find.text('60.0%'), findsOneWidget);
      final movedMarker = tester.getRect(
        find.byKey(const ValueKey('status-body-fat-marker')),
      );
      await tester.tap(find.byKey(const ValueKey('status-body-fat-minus')));
      await tester.pump();
      expect(bodyFat.text, '31.9');
      final restoredMarker = tester.getRect(
        find.byKey(const ValueKey('status-body-fat-marker')),
      );
      expect(movedMarker.left, greaterThan(restoredMarker.left));

      final gauge = find.byKey(const ValueKey('status-body-fat-segments'));
      final gaugeRect = tester.getRect(gauge);
      await tester.tapAt(
        Offset(gaugeRect.left + gaugeRect.width * .75, gaugeRect.center.dy),
      );
      await tester.pump();
      expect(double.parse(bodyFat.text), closeTo(45, .5));
      final highMarker = tester.getRect(
        find.byKey(const ValueKey('status-body-fat-marker')),
      );
      await tester.drag(gauge, Offset(-gaugeRect.width * .5, 0));
      await tester.pump();
      final lowerMarker = tester.getRect(
        find.byKey(const ValueKey('status-body-fat-marker')),
      );
      expect(double.parse(bodyFat.text), lessThan(45));
      expect(lowerMarker.left, lessThan(highMarker.left));
      bodyFat.text = '0.0';
      await tester.pump();
      final minimumMarker = tester.getRect(
        find.byKey(const ValueKey('status-body-fat-marker')),
      );
      bodyFat.text = '60.0';
      await tester.pump();
      final maximumMarker = tester.getRect(
        find.byKey(const ValueKey('status-body-fat-marker')),
      );
      expect(maximumMarker.left, greaterThan(minimumMarker.left));
      expect(
        find.byKey(const ValueKey('status-body-fat-plus')),
        findsOneWidget,
      );
    },
  );

  testWidgets('BASE CAMP sleep score uses fixed 0-100 LCD ruler', (
    tester,
  ) async {
    final sleep = TextEditingController(text: '7:00');
    final score = TextEditingController(text: '0');
    addTearDown(sleep.dispose);
    addTearDown(score.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
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
      ),
    );

    double markerLeft() => tester
        .getRect(find.byKey(const ValueKey('status-sleep-score-marker')))
        .left;
    var previous = markerLeft();
    for (final value in <int>[1, 57, 99, 100]) {
      score.text = '$value';
      await tester.pump();
      expect(find.text('$value /100'), findsOneWidget);
      final current = markerLeft();
      expect(current, greaterThanOrEqualTo(previous));
      previous = current;
    }
    await tester.tap(find.byKey(const ValueKey('status-sleep-score-minus')));
    await tester.pump();
    expect(score.text, '99');
    await tester.tap(find.byKey(const ValueKey('status-sleep-score-plus')));
    await tester.pump();
    expect(score.text, '100');
    final gauge = find.byKey(const ValueKey('status-sleep-score-ruler'));
    final rect = tester.getRect(gauge);
    await tester.tapAt(Offset(rect.left + rect.width * .57, rect.center.dy));
    await tester.pump();
    expect(score.text, '57');
    expect(tester.takeException(), isNull);
  });

  testWidgets('BASE CAMP foot meter supports LV.0, LV.3 and LV.10', (
    tester,
  ) async {
    final controller = TextEditingController(text: '0');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
        FootCard(controller: controller, initiallyExpanded: true),
      ),
    );

    expect(find.text('LV.0 /10'), findsOneWidget);
    expect(find.text('軽度'), findsOneWidget);
    expect(tester.widget<Text>(find.text('軽度')).style?.fontSize, 13);
    expect(
      find.byKey(const ValueKey('foot-pain-ten-segments')),
      findsOneWidget,
    );
    for (var level = 0; level <= 10; level++) {
      controller.text = '$level';
      await tester.pump();
      expect(find.text('LV.$level /10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const ValueKey('foot-pain-segment-3')));
    await tester.pump();
    expect(controller.text, '3');
    expect(find.text('LV.3 /10'), findsOneWidget);
    expect(find.text('監視'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('foot-pain-segment-5')));
    await tester.pump();
    expect(find.text('保護検討'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('foot-pain-segment-7')));
    await tester.pump();
    expect(find.text('強保護候補'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('foot-pain-segment-10')));
    await tester.pump();
    expect(controller.text, '10');
    expect(find.text('LV.10 /10'), findsOneWidget);
  });

  testWidgets('selected BASE CAMP sleep control explicitly inverts colors', (
    tester,
  ) async {
    final sleep = TextEditingController(text: '7:00');
    final score = TextEditingController(text: '80');
    addTearDown(sleep.dispose);
    addTearDown(score.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
        RecoveryCard(
          sleepController: sleep,
          sleepScoreController: score,
          sleepType: SleepType.sleep,
          onSleepTypeChanged: (_) {},
          sleepTimeUnmeasured: false,
          onSleepTimeUnmeasured: () {},
          onSleepTimeMeasured: () {},
        ),
      ),
    );

    final palette = tester
        .widget<BaseCampTerminalPaletteScope>(
          find.byType(BaseCampTerminalPaletteScope),
        )
        .palette;
    final selected = tester.widget<BaseCampMechanicalButton>(
      find.ancestor(
        of: find.text('睡眠'),
        matching: find.byType(BaseCampMechanicalButton),
      ),
    );
    expect(selected.selected, isTrue);
    expect(
      tester.widget<Text>(find.text('睡眠')).style?.color,
      palette.background,
    );
  });

  testWidgets('mechanical control sinks two pixels while held', (tester) async {
    final weight = TextEditingController(text: '94.2');
    final bodyFat = TextEditingController(text: '31.9');
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
        BodyCard(
          weightController: weight,
          bodyFatController: bodyFat,
          weightUnmeasured: false,
          onWeightUnmeasured: () {},
          onWeightMeasured: () {},
          initiallyExpanded: true,
        ),
      ),
    );

    final button = find.byKey(const ValueKey('status-weight-plus'));
    Matrix4 transform() => tester
        .widgetList<AnimatedContainer>(
          find.descendant(of: button, matching: find.byType(AnimatedContainer)),
        )
        .single
        .transform!;
    expect(transform().getTranslation().y, 0);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 100));
    expect(transform().getTranslation().y, 2);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(transform().getTranslation().y, 0);
  });

  testWidgets('LCD grids are owned only by STATUS LCD windows', (tester) async {
    final weight = TextEditingController(text: '94.2');
    final bodyFat = TextEditingController(text: '31.9');
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
        BodyCard(
          weightController: weight,
          bodyFatController: bodyFat,
          weightUnmeasured: false,
          onWeightUnmeasured: () {},
          onWeightMeasured: () {},
          initiallyExpanded: true,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('status-entry-physical-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('status-entry-bounded-lcd-display')),
      findsNothing,
    );
    for (final grid
        in find
            .byKey(const ValueKey('base-camp-terminal-lcd-grid'))
            .evaluate()) {
      var insideStatusWindow = false;
      grid.visitAncestorElements((ancestor) {
        if (ancestor.widget is BaseCampStatusLcdWindow) {
          insideStatusWindow = true;
          return false;
        }
        return true;
      });
      expect(insideStatusWindow, isTrue);
    }
    for (final controlKey in <String>[
      'status-weight-radio-scale',
      'status-weight-rotary-dial',
      'status-weight-plus',
      'status-weight-done',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(controlKey)),
          matching: find.byKey(const ValueKey('base-camp-terminal-lcd-grid')),
        ),
        findsNothing,
      );
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('status-weight-done'))),
      const Size(112, 40),
    );
  });

  for (final width in <double>[320, 375, 390, 430]) {
    testWidgets('finished LCD contract and LV.10 fit at ${width}dp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TextEditingController(text: '10');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _baseCampHarness(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 700)),
            child: FootCard(controller: controller, initiallyExpanded: true),
          ),
        ),
      );
      expect(find.text('LV.10 /10'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('foot-pain-done')));
      await tester.pump();
      final lcd = find.byKey(const ValueKey('foot-pain-lcd-window-collapsed'));
      expect(find.text('LV.10 /10'), findsOneWidget);
      expect(tester.getSize(lcd), Size(width < 375 ? 120 : 136, 42));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sleep type uses two equal 40dp physical columns', (
    tester,
  ) async {
    final sleep = TextEditingController(text: '7:00');
    final score = TextEditingController(text: '80');
    addTearDown(sleep.dispose);
    addTearDown(score.dispose);
    await tester.pumpWidget(
      _baseCampHarness(
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
      ),
    );
    final sleepButton = find.ancestor(
      of: find.text('睡眠'),
      matching: find.byType(BaseCampMechanicalButton),
    );
    final napButton = find.ancestor(
      of: find.text('仮眠').first,
      matching: find.byType(BaseCampMechanicalButton),
    );
    final sleepRect = tester.getRect(sleepButton);
    final napRect = tester.getRect(napButton);
    expect(sleepRect.height, 40);
    expect(napRect.height, 40);
    expect(sleepRect.width, closeTo(napRect.width, .01));
    expect(napRect.left - sleepRect.right, closeTo(8, .01));
  });

  testWidgets('STANDARD retains the existing STATUS instruments', (
    tester,
  ) async {
    final weight = TextEditingController(text: '94.2');
    final bodyFat = TextEditingController(text: '31.9');
    addTearDown(weight.dispose);
    addTearDown(bodyFat.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: BodyCard(
              weightController: weight,
              bodyFatController: bodyFat,
              weightUnmeasured: false,
              onWeightUnmeasured: () {},
              onWeightMeasured: () {},
              initiallyExpanded: true,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('status-weight-hud')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('status-weight-radio-tuner')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('status-body-fat-ring')), findsOneWidget);
  });

  for (final width in <double>[320, 375, 390, 430]) {
    for (final negative in <bool>[false, true]) {
      testWidgets('STATUS instruments fit ${width}dp INV=$negative', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 1500));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        DeviceSettingsController.instance.update(
          DeviceSettingsController.instance.value.copyWith(
            baseCampLcdNegative: negative,
          ),
        );
        final weight = TextEditingController(text: '94.2');
        final bodyFat = TextEditingController(text: '31.9');
        final sleep = TextEditingController(text: '7:00');
        final score = TextEditingController(text: '57');
        final foot = TextEditingController(text: '3');
        addTearDown(weight.dispose);
        addTearDown(bodyFat.dispose);
        addTearDown(sleep.dispose);
        addTearDown(score.dispose);
        addTearDown(foot.dispose);
        await tester.pumpWidget(
          _baseCampHarness(
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
                FootCard(controller: foot, initiallyExpanded: true),
              ],
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('status-weight-radio-scale')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-body-fat-segments')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-sleep-score-ruler')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('foot-pain-ten-segments')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-weight-lcd-window')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-body-fat-lcd-window')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-sleep-duration-lcd-window')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('status-sleep-score-lcd-window')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('foot-pain-lcd-window')),
          findsOneWidget,
        );
        for (final key in <String>[
          'status-body-fat-lcd-window',
          'status-sleep-score-lcd-window',
          'foot-pain-lcd-window',
        ]) {
          expect(tester.getSize(find.byKey(ValueKey(key))).height, 48);
        }
        for (final keys in <(String, String, String)>[
          (
            'status-body-fat-minus',
            'status-body-fat-plus',
            'status-body-fat-done',
          ),
          (
            'status-sleep-score-minus',
            'status-sleep-score-plus',
            'status-sleep-score-done',
          ),
          ('foot-pain-minus', 'foot-pain-plus', 'foot-pain-done'),
        ]) {
          final minus = tester.getRect(find.byKey(ValueKey(keys.$1)));
          final plus = tester.getRect(find.byKey(ValueKey(keys.$2)));
          final done = tester.getRect(find.byKey(ValueKey(keys.$3)));
          expect(minus.size, const Size(48, 40));
          expect(plus.size, const Size(48, 40));
          expect(done.size, const Size(100, 40));
          expect(plus.left - minus.right, 8);
          expect(done.left - plus.right, 8);
          expect(done.right - minus.left, 212);
        }
        expect(find.byIcon(Icons.lock_outline), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _rotateDial(
  WidgetTester tester,
  Finder dial, {
  required double turns,
}) async {
  final rect = tester.getRect(dial);
  final radius = rect.shortestSide * .42;
  Offset point(double angle) =>
      rect.center + Offset(math.cos(angle), math.sin(angle)) * radius;
  final gesture = await tester.startGesture(point(0));
  final steps = (turns.abs() * 48).ceil();
  for (var step = 1; step <= steps; step++) {
    final angle = turns * math.pi * 2 * step / steps;
    await gesture.moveTo(point(angle));
  }
  await gesture.up();
  await tester.pump();
}

Widget _baseCampHarness(Widget child) => MaterialApp(
  theme: BaseCampRetroTheme.apply(ThemeData.light()),
  home: BaseCampPresentation(
    screen: BaseCampScreen.morning,
    child: BaseCampRetroTerminalScreen(
      screenKey: 'status-instrument-test',
      child: Scaffold(
        body: BaseCampStatusEntrySurface(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    ),
  ),
);
