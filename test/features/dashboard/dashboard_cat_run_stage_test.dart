import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
              random: math.Random(7),
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
}
