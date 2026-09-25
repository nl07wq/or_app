import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/dashboard/dashboard_page.dart';
import 'package:or_app/features/dashboard/widgets/dashboard_cat_run_stage.dart';
import 'package:or_app/features/system/pages/cat_run_coat_patterns.dart';
import 'package:or_app/features/system/pages/cat_run_v23_production_preview.dart';
import 'package:or_app/features/system/pages/cat_run_v24_presentation.dart';

void main() {
  Future<void> pumpStage(
    WidgetTester tester, {
    required Duration minimumInterval,
    required Duration maximumInterval,
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: DashboardCatRunStage(
              random: _SequenceRandom([1, 0, 0, 1]),
              minimumInterval: minimumInterval,
              maximumInterval: maximumInterval,
            ),
          ),
        ),
      ),
    );
  }

  test('production CAT configuration retains five equal-probability coats', () {
    expect(CatRunCoatPatterns.visualVariants, hasLength(5));
    expect(
      CatRunCoatPatterns.visualVariants,
      containsAll(CatRunCoatVariant.values),
    );
    for (final variant in CatRunCoatPatterns.visualVariants) {
      expect(CatRunCoatPatterns.probabilities[variant], .2);
    }
    expect(CatRunV24Travel.crossingDuration, const Duration(seconds: 3));
    expect(DashboardCatRunStage.productionScale, .75);
    expect(
      DashboardCatRunStage.productionCatUnit,
      CatRunV23Travel.catUnit * .75,
    );
    expect(DashboardCatRunStage.groundInset, 5);
    expect(DashboardCatRunStage.groundLineColor, const Color(0xFF383838));
    const productionStage = DashboardCatRunStage();
    expect(productionStage.minimumInterval, const Duration(seconds: 30));
    expect(productionStage.maximumInterval, const Duration(seconds: 60));
    expect(DashboardCatRunStage.chainContinueProbability, .2);
    expect(DashboardCatRunStage.chainStopProbability, .8);
    expect(DashboardCatRunStage.chainFollowerTriggerProgress, .15);
    expect(DashboardCatRunStage.glitchProbability, .05);
    expect(DashboardCatRunStage.normalEventProbability, .95);
    expect(DashboardCatRunStage.glitchCatCount, 10);
    expect(DashboardCatRunStage.glitchFollowerTriggerProgress, .08);
    expect(
      DashboardCatRunStage.eventKindForRoll(0),
      DashboardCatEventKind.glitch,
    );
    for (final roll in List<int>.generate(19, (index) => index + 1)) {
      expect(
        DashboardCatRunStage.eventKindForRoll(roll),
        DashboardCatEventKind.normal,
      );
    }
    expect(DashboardCatRunStage.chainContinuesForRoll(0), isTrue);
    for (final roll in [1, 2, 3, 4]) {
      expect(DashboardCatRunStage.chainContinuesForRoll(roll), isFalse);
    }

    final forcedChain = CatRunProductionEventPlan.forceChain(
      random: _SequenceRandom([0, 1, 2]),
      direction: CatRunV23Direction.leftToRight,
    );
    expect(forcedChain.source, CatRunProductionEventSource.sandbox);
    expect(forcedChain.isGlitch, isFalse);
    expect(forcedChain.allowsRecursiveContinuation, isFalse);
    expect(forcedChain.crossings, hasLength(3));
    expect(
      forcedChain.crossings[1].startedAtProgress,
      DashboardCatRunStage.chainFollowerTriggerProgress,
    );
    final forcedGlitch = CatRunProductionEventPlan.forceGlitch(
      random: _SequenceRandom([0, 1, 2, 3, 4]),
      direction: CatRunV23Direction.rightToLeft,
    );
    expect(forcedGlitch.isGlitch, isTrue);
    expect(forcedGlitch.crossings, hasLength(10));
    expect(forcedGlitch.allowsRecursiveContinuation, isFalse);
    expect(
      forcedGlitch.crossings[1].startedAtProgress,
      DashboardCatRunStage.glitchFollowerTriggerProgress,
    );
  });

  test(
    'one stage transitions between a pinned viewport position and its natural row',
    () {
      const viewport = Size(390, 700);
      final pinned = dashboardAdaptiveCatStageRect(
        naturalSlotRect: const Rect.fromLTWH(16, 1100, 358, 48),
        viewportSize: viewport,
        safeBottom: 20,
      );
      final natural = dashboardAdaptiveCatStageRect(
        naturalSlotRect: const Rect.fromLTWH(16, 580, 358, 48),
        viewportSize: viewport,
        safeBottom: 20,
      );

      expect(pinned.top, 632);
      expect(natural.top, 580);
      expect(pinned.size, const Size(358, DashboardCatRunStage.height));
      expect(natural.size, const Size(358, DashboardCatRunStage.height));
    },
  );

  testWidgets('waits before the initial appearance and schedules after exit', (
    tester,
  ) async {
    await pumpStage(
      tester,
      minimumInterval: const Duration(milliseconds: 50),
      maximumInterval: const Duration(milliseconds: 50),
    );

    expect(find.byKey(DashboardCatRunStage.stageKey), findsOneWidget);
    expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 49));
    expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(DashboardCatRunStage.activeKey), findsOneWidget);

    await tester.pump(
      CatRunV24Travel.crossingDuration + const Duration(milliseconds: 1),
    );
    await tester.pump();
    expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 49));
    expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
  });

  testWidgets('reduced motion keeps the production stage empty', (
    tester,
  ) async {
    await pumpStage(
      tester,
      minimumInterval: Duration.zero,
      maximumInterval: Duration.zero,
      reducedMotion: true,
    );
    await tester.pump();

    expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
  });

  testWidgets(
    'a continued chain keeps direction and independently samples the follower coat',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCatRunStage(
              random: _SequenceRandom([1, 0, 0, 0, 1, 1]),
              minimumInterval: Duration.zero,
              maximumInterval: Duration.zero,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump();

      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(DashboardCatRunStage.activeKey),
                  )
                  .painter!
              as CatRunV23StagePainter;
      expect(painter.progress, greaterThanOrEqualTo(.15));
      expect(painter.crossings, hasLength(2));
      expect(
        painter.crossings!.map((crossing) => crossing.direction),
        everyElement(CatRunV23Direction.leftToRight),
      );
      expect(painter.crossings!.map((crossing) => crossing.coatVariant), [
        CatRunCoatVariant.normal,
        CatRunCoatVariant.hachiware,
      ]);
      expect(painter.crossings![1].progress, closeTo(0, .02));
    },
  );

  testWidgets('a follower receives its own continuation roll without a cap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardCatRunStage(
            random: _SequenceRandom([1, 0, 0, 0, 1, 0, 2, 1]),
            minimumInterval: Duration.zero,
            maximumInterval: Duration.zero,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump();

    final painter =
        tester
                .widget<CustomPaint>(find.byKey(DashboardCatRunStage.activeKey))
                .painter!
            as CatRunV23StagePainter;
    expect(painter.crossings, hasLength(3));
    expect(painter.crossings!.map((crossing) => crossing.coatVariant), [
      CatRunCoatVariant.normal,
      CatRunCoatVariant.hachiware,
      CatRunCoatVariant.calico,
    ]);
  });

  testWidgets('chain stage remains paintable at production target widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0, 900.0]) {
      tester.view.physicalSize = Size(width, 200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCatRunStage(
              key: ValueKey(width),
              random: _SequenceRandom([1, 0, 0, 0, 1, 1]),
              minimumInterval: Duration.zero,
              maximumInterval: Duration.zero,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 2200));
      expect(find.byKey(DashboardCatRunStage.activeKey), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets(
    'manual trigger starts the normal event once, cancels the pending timer, and rejects rapid taps',
    (tester) async {
      final stageKey = GlobalKey<DashboardCatRunStageState>();
      final activity = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCatRunStage(
              key: stageKey,
              random: _SequenceRandom([1, 0, 1, 1]),
              minimumInterval: const Duration(milliseconds: 50),
              maximumInterval: const Duration(milliseconds: 50),
              onEventActiveChanged: activity.add,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(stageKey.currentState!.triggerManualAppearance(), isTrue);
      expect(activity, [true]);
      expect(stageKey.currentState!.triggerManualAppearance(), isFalse);
      expect(activity, [true]);
      await tester.pump();
      expect(find.byKey(DashboardCatRunStage.activeKey), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 50));
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(DashboardCatRunStage.activeKey),
                  )
                  .painter!
              as CatRunV23StagePainter;
      expect(painter.crossings, hasLength(1));

      await tester.pump(
        CatRunV24Travel.crossingDuration + const Duration(milliseconds: 1),
      );
      await tester.pump();
      expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
      expect(activity, [true, false]);
      await tester.pump(const Duration(milliseconds: 49));
      expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
    },
  );

  testWidgets(
    'CAT GLITCH creates exactly ten tightly spaced cats without continuation',
    (tester) async {
      final stageKey = GlobalKey<DashboardCatRunStageState>();
      final activity = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCatRunStage(
              key: stageKey,
              random: _SequenceRandom([0, 0, 0, 1, 2, 3, 4, 0, 1, 2, 3, 4]),
              minimumInterval: const Duration(milliseconds: 50),
              maximumInterval: const Duration(milliseconds: 50),
              onEventActiveChanged: activity.add,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(stageKey.currentState!.triggerManualAppearance(), isTrue);
      expect(activity, [true]);
      await tester.pump();
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(DashboardCatRunStage.activeKey),
                  )
                  .painter!
              as CatRunV23StagePainter;
      expect(painter.crossings, hasLength(DashboardCatRunStage.glitchCatCount));
      expect(
        painter.crossings!.map((crossing) => crossing.direction),
        everyElement(CatRunV23Direction.leftToRight),
      );
      expect(painter.crossings!.map((crossing) => crossing.coatVariant), [
        CatRunCoatVariant.normal,
        CatRunCoatVariant.hachiware,
        CatRunCoatVariant.calico,
        CatRunCoatVariant.kijitora,
        CatRunCoatVariant.sabi,
        CatRunCoatVariant.normal,
        CatRunCoatVariant.hachiware,
        CatRunCoatVariant.calico,
        CatRunCoatVariant.kijitora,
        CatRunCoatVariant.sabi,
      ]);
      final starts = painter.crossings!
          .map((crossing) => painter.progress - crossing.progress)
          .toList();
      for (var index = 1; index < starts.length; index++) {
        expect(
          starts[index] - starts[index - 1],
          closeTo(DashboardCatRunStage.glitchFollowerTriggerProgress, .000001),
        );
      }
      expect(
        DashboardCatRunStage.glitchFollowerTriggerProgress,
        lessThan(DashboardCatRunStage.chainFollowerTriggerProgress),
      );

      await tester.pump(const Duration(seconds: 2));
      final laterPainter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(DashboardCatRunStage.activeKey),
                  )
                  .painter!
              as CatRunV23StagePainter;
      expect(
        laterPainter.crossings,
        hasLength(DashboardCatRunStage.glitchCatCount),
      );
      expect(activity, [true]);
    },
  );

  testWidgets(
    'AUTO and manual use the same one-roll selector and emit auditable metadata',
    (tester) async {
      final automatic = <DashboardCatEventMetadata>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCatRunStage(
              random: _SequenceRandom([0, 1, 0, 1, 2, 3, 4]),
              minimumInterval: Duration.zero,
              maximumInterval: Duration.zero,
              onEventMetadataChanged: automatic.add,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final autoStart = automatic.first;
      expect(autoStart.source, CatRunProductionEventSource.automatic);
      expect(autoStart.eventRoll, 0);
      expect(autoStart.eventKind, DashboardCatEventKind.glitch);
      expect(autoStart.plannedCatCount, 10);
      expect(autoStart.spawnedCatCount, 10);
      expect(autoStart.completedCatCount, 0);
      expect(autoStart.active, isTrue);

      final stageKey = GlobalKey<DashboardCatRunStageState>();
      final manual = <DashboardCatEventMetadata>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCatRunStage(
              key: stageKey,
              random: _SequenceRandom([0, 1, 0, 1, 2, 3, 4]),
              minimumInterval: const Duration(seconds: 10),
              maximumInterval: const Duration(seconds: 10),
              onEventMetadataChanged: manual.add,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(stageKey.currentState!.triggerManualAppearance(), isTrue);
      final manualStart = manual.first;
      expect(manualStart.source, CatRunProductionEventSource.manual);
      expect(manualStart.eventRoll, 0);
      expect(manualStart.eventKind, DashboardCatEventKind.glitch);
      expect(manualStart.plannedCatCount, 10);
      expect(manualStart.direction, CatRunV23Direction.rightToLeft);
    },
  );

  testWidgets('GLITCH remains active until all ten crossings have exited', (
    tester,
  ) async {
    final metadata = <DashboardCatEventMetadata>[];
    final stageKey = GlobalKey<DashboardCatRunStageState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardCatRunStage(
            key: stageKey,
            random: _SequenceRandom([0, 0, 0, 1, 2, 3, 4]),
            minimumInterval: const Duration(seconds: 10),
            maximumInterval: const Duration(seconds: 10),
            onEventMetadataChanged: metadata.add,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(stageKey.currentState!.triggerManualAppearance(), isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(DashboardCatRunStage.activeKey), findsOneWidget);
    expect(metadata.last.active, isTrue);
    expect(metadata.last.completedCatCount, lessThan(10));

    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);
    expect(metadata.last.active, isFalse);
    expect(metadata.last.completed, isTrue);
    expect(metadata.last.completedCatCount, 10);
  });

  testWidgets(
    'Dashboard paw control is responsive and starts the shared production CAT stage',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final semantics = tester.ensureSemantics();

      final paw = find.byKey(const ValueKey('dashboard-cat-manual-trigger'));
      final sign = find.byKey(const ValueKey('dashboard-neon-physical-sign'));
      for (final width in [320.0, 390.0, 900.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpWidget(const MaterialApp(home: DashboardPage()));
        await tester.pump();

        expect(paw, findsOneWidget, reason: 'width $width');
        expect(tester.getSize(paw), const Size(44, 44));
        expect(tester.getSemantics(paw).label, contains('Run cat'));
        expect(
          tester
              .widget<Icon>(
                find.descendant(of: paw, matching: find.byType(Icon)),
              )
              .color,
          DashboardCatPawColors.ready,
        );
        expect(sign, findsOneWidget, reason: 'width $width');
        expect(
          tester.getRect(paw).right,
          lessThan(tester.getRect(sign).left - 10),
        );
        expect(tester.takeException(), isNull, reason: 'width $width');
      }

      expect(find.byKey(DashboardCatRunStage.activeKey), findsNothing);

      await tester.tap(paw);
      await tester.pump();
      expect(find.byKey(DashboardCatRunStage.activeKey), findsOneWidget);
      expect(
        tester
            .widget<Icon>(find.descendant(of: paw, matching: find.byType(Icon)))
            .color,
        DashboardCatPawColors.active,
      );
      expect(
        tester
            .widget<IconButton>(
              find.descendant(of: paw, matching: find.byType(IconButton)),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.getSemantics(paw).label, contains('Run cat'));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}

class _SequenceRandom implements math.Random {
  _SequenceRandom(this._values);

  final List<int> _values;
  var _index = 0;

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => nextInt(1000000) / 1000000;

  @override
  int nextInt(int max) {
    final value = _values[_index++ % _values.length];
    return value % max;
  }
}
