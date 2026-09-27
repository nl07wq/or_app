import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/pages/animations_sandbox_page.dart';
import 'package:or_app/features/system/pages/bat_v3_flight_motion_poc.dart';
import 'package:or_app/features/system/pages/bat_v3_source_data.dart';

void main() {
  test(
    'V4 canonical cels have one canvas, one body origin, and normalized axes',
    () {
      expect(BatV3SourceSet.poses, hasLength(5));
      expect(BatV3SourceSet.poses.map((p) => p.name), const [
        'NEUTRAL',
        'TOP INTERMEDIATE',
        'TOP',
        'BOTTOM INTERMEDIATE',
        'BOTTOM',
      ]);
      expect(BatV3SourceSet.canonicalCanvas, const Size(1800, 1700));
      expect(BatV3SourceSet.canonicalBodyAnchor, const Offset(800, 850));
      for (final pose in BatV3SourceSet.poses) {
        expect(pose.canonicalAsset, contains('bat_v3/canonical/'));
        expect(
          pose.canonicalBodyAxis,
          closeTo(BatV3SourceSet.canonicalBodyAxis, .01),
        );
        expect(
          BatV3SourceSet.isFullyContained(pose),
          isTrue,
          reason: pose.name,
        );
      }
    },
  );

  test('V4 retains the explicit source stroke, timing, and Y-only flutter', () {
    expect(BatV3SourceSet.cycle, const [0, 1, 2, 1, 0, 3, 4, 3]);
    expect(BatV3SourceSet.flutterOffsets, const [0, -2, -4, -2, 0, 2, 4, 2]);
    expect(BatV3SourceSet.catProductionGrayArgb, 0xFF7A7A7A);
  });

  testWidgets('V4 canonical PNG cels are registered app assets', (
    tester,
  ) async {
    for (final pose in BatV3SourceSet.poses) {
      final bytes = await rootBundle.load(pose.canonicalAsset);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: pose.name);
    }
  });

  testWidgets('V4 exposes canonical and body-overlay inspection only', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_host());
    expect(find.byKey(const ValueKey('bat-v3-view-canonical')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bat-v3-view-bodyOverlay')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('bat-v3-view-raw')), findsNothing);
    expect(find.byKey(const ValueKey('bat-v3-view-mask')), findsNothing);
    expect(find.byKey(const ValueKey('bat-v3-view-registered')), findsNothing);
    expect(find.textContaining('PAUSED · 125 ms / POSE'), findsOneWidget);
  });

  testWidgets(
    'V4 keeps canonical playback, selected crossing size, and direction controls',
    (tester) async {
      _viewport(tester);
      await tester.pumpWidget(_host());
      await tester.tap(find.byKey(const ValueKey('bat-v3-restart')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('FRAME 03 · TOP'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('bat-v3-crossing')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bat-v3-crossing-stage')),
        findsOneWidget,
      );
      for (final scale in ['1.00', '0.50', '0.25']) {
        await tester.tap(find.byKey(ValueKey('bat-v3-scale-$scale')));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: scale);
      }
      await tester.tap(find.byKey(const ValueKey('bat-v3-rtl')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('V4 remains responsive without legacy CAT POC restoration', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 6000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_host());
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    await tester.pumpWidget(const MaterialApp(home: AnimationsSandboxPage()));
    expect(find.byKey(const ValueKey('bat-v3-source-audit')), findsOneWidget);
    expect(find.text('CAT TRACE PIPELINE POC'), findsNothing);
  });

  testWidgets('Production Preview V2.1 exposes only the candidate controls', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_productionHost());
    expect(
      find.byKey(const ValueKey('bat-v3-production-preview')),
      findsOneWidget,
    );
    expect(find.textContaining('FRAME 01 · 60ms'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('bat-v3-production-stage')),
      findsOneWidget,
    );
    for (final key in [
      'bat-v3-production-play-restart',
      'bat-v3-production-flutter-off',
      'bat-v3-production-flutter-on',
      'bat-v3-production-speed-1x',
      'bat-v3-production-speed-half',
      'bat-v3-production-count-1',
      'bat-v3-production-count-2',
      'bat-v3-production-count-3',
      'bat-v3-production-count-random',
      'bat-v3-production-force-glitch',
      'bat-v3-production-ltr',
      'bat-v3-production-rtl',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: key);
    }
    for (final oldKey in [
      'bat-v3-production-timing-60',
      'bat-v3-production-timing-100',
      'bat-v3-production-timing-150',
      'bat-v3-production-flutter-4',
      'bat-v3-production-flutter-6',
      'bat-v3-production-flutter-8',
      'bat-v3-production-pause',
      'bat-v3-production-speed-2200ms',
    ]) {
      expect(find.byKey(ValueKey(oldKey)), findsNothing, reason: oldKey);
    }
  });

  testWidgets('Production Preview V2 keeps a fixed 60ms pose clock', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_productionHost());
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-play-restart')),
    );
    await tester.pump();
    expect(find.textContaining('FRAME 01 · 60ms'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('FRAME 02 · 60ms'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('FRAME 03 · 60ms'), findsOneWidget);
  });

  test(
    'Production preview crosses full width and applies flutter in screen px',
    () {
      for (final width in [320.0, 390.0, 900.0]) {
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 0,
            leftToRight: true,
          ),
          closeTo(
            -BatV3ProductionFlight.visibleBatMaxX -
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 1,
            leftToRight: true,
          ),
          closeTo(
            width -
                BatV3ProductionFlight.visibleBatMinX +
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 0,
            leftToRight: false,
          ),
          closeTo(
            width -
                BatV3ProductionFlight.visibleBatMinX +
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
        expect(
          BatV3ProductionFlight.leftFor(
            stageWidth: width,
            progress: 1,
            leftToRight: false,
          ),
          closeTo(
            -BatV3ProductionFlight.visibleBatMaxX -
                BatV3ProductionFlight.entryExitGap,
            .001,
          ),
        );
      }
      const base =
          (BatV3ProductionFlight.stageHeight -
              BatV3ProductionFlight.batHeight) /
          2;
      expect(BatV3ProductionFlight.topFor(0), base);
      expect(BatV3ProductionFlight.topFor(-2), base - 2);
      expect(BatV3ProductionFlight.topFor(-4), base - 4);
      expect(BatV3ProductionFlight.topFor(2), base + 2);
      expect(BatV3ProductionFlight.topFor(4), base + 4);
      expect(BatV3ProductionFlight.fullSpeedDurationMs, 2200);
      expect(BatV3ProductionFlight.halfSpeedDurationMs, 4400);
    },
  );

  test(
    'Production Preview V2 fixes the accepted 8px screen-space flutter phase',
    () {
      final actual = List<double>.generate(
        8,
        (index) => BatV3ProductionFlight.flutterOffset(
          cycleIndex: index,
          amplitude: BatV3ProductionFlight.flutterAmplitude,
          enabled: true,
        ),
      );
      expect(actual, [0, -4, -8, -4, 0, 4, 8, 4]);
      final off = List<double>.generate(
        8,
        (index) => BatV3ProductionFlight.flutterOffset(
          cycleIndex: index,
          amplitude: BatV3ProductionFlight.flutterAmplitude,
          enabled: false,
        ),
      );
      expect(off, List<double>.filled(8, 0));
    },
  );

  test(
    'V2 group formation is deterministic and completes after the last bat',
    () {
      final instances = BatV3ProductionFlight.instances;
      expect(instances.map((instance) => instance.phaseOffset), [0, 2, 5]);
      expect(instances.map((instance) => instance.startDelayMs), [0, 180, 360]);
      expect(instances.map((instance) => instance.formationY), [0, -12, 10]);
      for (final instance in instances) {
        expect(
          BatV3ProductionFlight.progressFor(
            elapsedMs: 0,
            durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
            instance: instance,
          ),
          0,
        );
        expect(
          BatV3ProductionFlight.progressFor(
            elapsedMs:
                BatV3ProductionFlight.fullSpeedDurationMs +
                instance.startDelayMs,
            durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
            instance: instance,
          ),
          1,
        );
        for (var index = 0; index < BatV3SourceSet.cycle.length; index++) {
          final y = BatV3ProductionFlight.topFor(
            instance.formationY +
                BatV3ProductionFlight.flutterOffset(
                  cycleIndex:
                      (index + instance.phaseOffset) %
                      BatV3SourceSet.cycle.length,
                  amplitude: BatV3ProductionFlight.flutterAmplitude,
                  enabled: true,
                ),
          );
          expect(y, greaterThanOrEqualTo(0));
          expect(
            y + BatV3ProductionFlight.batHeight,
            lessThanOrEqualTo(BatV3ProductionFlight.stageHeight),
          );
        }
      }
      expect(
        BatV3ProductionFlight.progressFor(
          elapsedMs: BatV3ProductionFlight.fullSpeedDurationMs,
          durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
          instance: instances.last,
        ),
        lessThan(1),
      );
      expect(BatV3ProductionFlight.poseDurationMs, 60);
      expect(BatV3ProductionFlight.crossingDurationForSpeed('1×'), 2200);
      expect(BatV3ProductionFlight.crossingDurationForSpeed('0.5×'), 4400);
    },
  );

  test('V2.1 removes completed instances before the next event', () {
    for (final instance in BatV3ProductionFlight.instances) {
      final end =
          BatV3ProductionFlight.fullSpeedDurationMs + instance.startDelayMs;
      expect(
        BatV3ProductionFlight.isInstanceComplete(
          elapsedMs: end - 1,
          durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
          instance: instance,
        ),
        isFalse,
      );
      expect(
        BatV3ProductionFlight.isInstanceComplete(
          elapsedMs: end,
          durationMs: BatV3ProductionFlight.fullSpeedDurationMs,
          instance: instance,
        ),
        isTrue,
      );
    }
  });

  test('FORCE GLITCH ×10 uses a deterministic contained swarm formation', () {
    final instances = BatV3ProductionFlight.glitchInstances;
    expect(instances, hasLength(10));
    expect(instances.map((instance) => instance.identifier), [
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
    ]);
    expect(instances.map((instance) => instance.phaseOffset), [
      0,
      2,
      5,
      1,
      4,
      7,
      3,
      6,
      2,
      5,
    ]);
    expect(instances.map((instance) => instance.startDelayMs), [
      0,
      80,
      160,
      240,
      320,
      400,
      480,
      560,
      640,
      720,
    ]);
    expect(instances.map((instance) => instance.formationY), [
      0,
      -12,
      -6,
      6,
      12,
      18,
      -18,
      -15,
      -9,
      9,
    ]);
    for (final instance in instances) {
      for (var index = 0; index < BatV3SourceSet.cycle.length; index++) {
        final top = BatV3ProductionFlight.topFor(
          instance.formationY +
              BatV3ProductionFlight.flutterOffset(
                cycleIndex:
                    (index + instance.phaseOffset) %
                    BatV3SourceSet.cycle.length,
                amplitude: BatV3ProductionFlight.flutterAmplitude,
                enabled: true,
              ),
        );
        expect(top, greaterThanOrEqualTo(0));
        expect(
          top + BatV3ProductionFlight.batHeight,
          lessThanOrEqualTo(BatV3ProductionFlight.stageHeight),
        );
      }
    }
  });

  testWidgets('FORCE GLITCH ×10 replaces the normal event and clears on exit', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_productionHost());
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-force-glitch')),
    );
    await tester.pump();
    for (var identifier = 0; identifier < 10; identifier++) {
      expect(
        find.byKey(ValueKey('bat-v3-production-instance-$identifier')),
        findsOneWidget,
      );
    }
    await tester.pump(const Duration(milliseconds: 2928));
    for (var identifier = 0; identifier < 10; identifier++) {
      expect(
        find.byKey(ValueKey('bat-v3-production-instance-$identifier')),
        findsNothing,
      );
    }
  });

  testWidgets(
    'FORCE GLITCH ×10 respects selected direction, speed, and flutter',
    (tester) async {
      for (final scenario in [
        (
          'bat-v3-production-ltr',
          'bat-v3-production-speed-1x',
          'bat-v3-production-flutter-on',
        ),
        (
          'bat-v3-production-rtl',
          'bat-v3-production-speed-1x',
          'bat-v3-production-flutter-on',
        ),
        (
          'bat-v3-production-ltr',
          'bat-v3-production-speed-half',
          'bat-v3-production-flutter-off',
        ),
        (
          'bat-v3-production-rtl',
          'bat-v3-production-speed-half',
          'bat-v3-production-flutter-off',
        ),
      ]) {
        _viewport(tester);
        await tester.pumpWidget(_productionHost());
        await tester.tap(find.byKey(ValueKey(scenario.$1)));
        await tester.tap(find.byKey(ValueKey(scenario.$2)));
        await tester.tap(find.byKey(ValueKey(scenario.$3)));
        await tester.tap(
          find.byKey(const ValueKey('bat-v3-production-force-glitch')),
        );
        await tester.pump();
        expect(
          _productionTelemetry(tester),
          contains(scenario.$1.endsWith('rtl') ? 'R→L' : 'L→R'),
        );
        expect(
          _productionTelemetry(tester),
          contains(scenario.$2.endsWith('half') ? '0.5×' : '1×'),
        );
        expect(
          _productionTelemetry(tester),
          contains(scenario.$3.endsWith('off') ? 'FLUTTER OFF' : 'FLUTTER 8px'),
        );
        expect(
          find.byKey(const ValueKey('bat-v3-production-instance-9')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('V2.1 endlessly repeats ×1 with a zero-residue boundary', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_productionHost());
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-play-restart')),
    );
    await tester.pump(const Duration(milliseconds: 2208));
    expect(
      find.byKey(const ValueKey('bat-v3-production-instance-0')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(const ValueKey('bat-v3-production-instance-0')),
      findsOneWidget,
    );
  });

  testWidgets('V2.1 clears completed cels at both directional boundaries', (
    tester,
  ) async {
    for (final directionKey in [
      'bat-v3-production-ltr',
      'bat-v3-production-rtl',
    ]) {
      _viewport(tester);
      await tester.pumpWidget(_productionHost());
      await tester.tap(find.byKey(ValueKey(directionKey)));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('bat-v3-production-play-restart')),
      );
      await tester.pump(const Duration(milliseconds: 2208));
      expect(
        find.byKey(const ValueKey('bat-v3-production-instance-0')),
        findsNothing,
        reason: directionKey,
      );
    }
  });

  testWidgets('V2.1 waits for the delayed final ×3 bat before repeating', (
    tester,
  ) async {
    _viewport(tester);
    await tester.pumpWidget(_productionHost());
    await tester.tap(find.byKey(const ValueKey('bat-v3-production-count-3')));
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-play-restart')),
    );
    await tester.pump(const Duration(milliseconds: 2208));
    expect(
      find.byKey(const ValueKey('bat-v3-production-instance-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('bat-v3-production-instance-5')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 352));
    expect(
      find.byKey(const ValueKey('bat-v3-production-instance-5')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 16));
    for (final phase in [0, 2, 5]) {
      expect(
        find.byKey(ValueKey('bat-v3-production-instance-$phase')),
        findsOneWidget,
      );
    }
  });

  testWidgets('V2.1 samples RANDOM count once per endless event', (
    tester,
  ) async {
    final samples = [1, 0, 2, 1];
    var sampleIndex = 0;
    _viewport(tester);
    await tester.pumpWidget(
      _productionHost(nextInt: (_) => samples[sampleIndex++]),
    );
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-count-random')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-play-restart')),
    );
    await tester.pump();
    expect(_productionTelemetry(tester), contains('RANDOM → ×2'));
    await tester.pump(const Duration(milliseconds: 2384));
    expect(
      find.byKey(const ValueKey('bat-v3-production-instance-0')),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(_productionTelemetry(tester), contains('RANDOM → ×1'));
    await tester.pump(const Duration(milliseconds: 2208));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_productionTelemetry(tester), contains('RANDOM → ×3'));
  });

  testWidgets(
    'V2.1 defers count changes until the next event and restarts cleanly',
    (tester) async {
      _viewport(tester);
      await tester.pumpWidget(_productionHost());
      await tester.tap(
        find.byKey(const ValueKey('bat-v3-production-play-restart')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('bat-v3-production-count-3')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bat-v3-production-instance-2')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('bat-v3-production-play-restart')),
      );
      await tester.pump();
      for (final phase in [0, 2, 5]) {
        expect(
          find.byKey(ValueKey('bat-v3-production-instance-$phase')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('V2.1 restart samples a fresh RANDOM event count', (
    tester,
  ) async {
    final samples = [2, 0];
    var sampleIndex = 0;
    _viewport(tester);
    await tester.pumpWidget(
      _productionHost(nextInt: (_) => samples[sampleIndex++]),
    );
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-count-random')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-play-restart')),
    );
    await tester.pump();
    expect(_productionTelemetry(tester), contains('RANDOM → ×3'));
    await tester.tap(
      find.byKey(const ValueKey('bat-v3-production-play-restart')),
    );
    await tester.pump();
    expect(_productionTelemetry(tester), contains('RANDOM → ×1'));
  });

  testWidgets(
    'V2 renders the selected deterministic group at 320, 390, and 900',
    (tester) async {
      for (final width in [320.0, 390.0, 900.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_productionHost());
        await tester.tap(
          find.byKey(const ValueKey('bat-v3-production-count-3')),
        );
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('bat-v3-production-play-restart')),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byKey(const ValueKey('bat-v3-production-instance-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bat-v3-production-instance-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('bat-v3-production-instance-5')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: '${width}px');
      }
    },
  );
}

Widget _host() => MaterialApp(
  home: Scaffold(body: ListView(children: const [BatV3FlightMotionPoc()])),
);
Widget _productionHost({int Function(int max)? nextInt}) => MaterialApp(
  home: Scaffold(
    body: ListView(children: [BatV3ProductionPreview(nextInt: nextInt)]),
  ),
);
void _viewport(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
}

String _productionTelemetry(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('bat-v3-production-telemetry')))
    .data!;
