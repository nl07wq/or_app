import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_colors.dart';
import 'package:or_app/features/dashboard/widgets/dashboard_ambient_wildlife_stage.dart';

void main() {
  Widget subject({
    DateTime Function()? now,
    int Function(int max)? nextInt,
    Duration minimumInterval = const Duration(seconds: 45),
    Duration maximumInterval = const Duration(seconds: 150),
    bool reducedMotion = false,
    double width = 390,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Scaffold(
        body: SizedBox(
          width: width,
          child: DashboardAmbientWildlifeStage(
            localNow: now ?? DateTime.now,
            nextInt: nextInt,
            minimumInterval: minimumInterval,
            maximumInterval: maximumInterval,
          ),
        ),
      ),
    ),
  );

  DashboardAmbientWildlifePainter painterFor(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('dashboard-ambient-wildlife-cat')),
              )
              .painter!
          as DashboardAmbientWildlifePainter;

  test('local clock boundaries select the correct wildlife period', () {
    expect(
      wildlifePeriodFor(DateTime(2026, 9, 19, 5, 59)),
      WildlifePeriod.night,
    );
    expect(wildlifePeriodFor(DateTime(2026, 9, 19, 6)), WildlifePeriod.day);
    expect(
      wildlifePeriodFor(DateTime(2026, 9, 19, 17, 59)),
      WildlifePeriod.day,
    );
    expect(wildlifePeriodFor(DateTime(2026, 9, 19, 18)), WildlifePeriod.night);
    expect(wildlifeKindsFor(WildlifePeriod.day), const [
      WildlifeKind.cat,
      WildlifeKind.birds,
    ]);
    expect(wildlifeKindsFor(WildlifePeriod.night), const [
      WildlifeKind.fox,
      WildlifeKind.bat,
    ]);
  });

  test(
    'shared neutral palette separates every wildlife silhouette from production dark background',
    () {
      const palette = DashboardAmbientWildlifePalette.dark;
      final background = DashboardAmbientWildlifePalette.productionBackground;
      final effectiveWildlife = Color.alphaBlend(
        palette.silhouette,
        background,
      );
      final effectiveGround = Color.alphaBlend(palette.groundLine, background);

      expect(palette.silhouette, isNot(Colors.black));
      expect(palette.silhouette, isNot(background));
      expect(effectiveWildlife.computeLuminance(), greaterThan(.25));
      expect(
        effectiveWildlife.computeLuminance() - background.computeLuminance(),
        greaterThan(.20),
      );
      expect(
        AppColors.textPrimary.computeLuminance(),
        greaterThan(effectiveWildlife.computeLuminance()),
      );
      expect(
        effectiveWildlife.computeLuminance(),
        greaterThan(effectiveGround.computeLuminance()),
      );
    },
  );

  test('cat, fox, birds, and bat plans resolve through one shared palette', () {
    const palette = DashboardAmbientWildlifePalette.dark;
    for (final kind in WildlifeKind.values) {
      final painter = DashboardAmbientWildlifePainter(
        plan: WildlifeEventPlan(
          kind: kind,
          leftToRight: true,
          count: 1,
          phaseSeed: 0,
          speedPixelsPerSecond: 100,
        ),
        progress: const AlwaysStoppedAnimation(0),
        palette: palette,
      );
      expect(painter.palette.silhouette, palette.silhouette);
      expect(painter.palette.groundLine, palette.groundLine);
    }
  });

  test(
    'explicit preview plans retain production speeds and representative counts',
    () {
      const expectedCounts = {
        WildlifeKind.cat: 1,
        WildlifeKind.fox: 1,
        WildlifeKind.birds: 3,
        WildlifeKind.bat: 2,
      };
      for (final kind in WildlifeKind.values) {
        final plan = wildlifePreviewPlan(kind: kind, leftToRight: false);
        expect(plan.leftToRight, isFalse);
        expect(plan.count, expectedCounts[kind]);
        expect(plan.speedPixelsPerSecond, wildlifeSpeedFor(kind));
      }
    },
  );

  test(
    'event plans clamp responsive travel duration while retaining speed',
    () {
      const cat = WildlifeEventPlan(
        kind: WildlifeKind.cat,
        leftToRight: true,
        count: 1,
        phaseSeed: 0,
        speedPixelsPerSecond: 140,
      );
      const birds = WildlifeEventPlan(
        kind: WildlifeKind.birds,
        leftToRight: true,
        count: 3,
        phaseSeed: 0,
        speedPixelsPerSecond: 110,
      );
      expect(cat.durationForWidth(320), const Duration(milliseconds: 2714));
      expect(cat.durationForWidth(900), const Duration(milliseconds: 3200));
      expect(birds.durationForWidth(320), const Duration(milliseconds: 3382));
      expect(birds.durationForWidth(900), const Duration(milliseconds: 5000));
    },
  );

  testWidgets(
    'stage is a quiet 48px decorative IgnorePointer lane at all widths',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 390.0, 900.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpWidget(subject(width: width));
        final stage = find.byKey(
          const ValueKey('dashboard-ambient-wildlife-stage'),
        );
        expect(stage, findsOneWidget);
        expect(
          tester.getSize(stage).height,
          DashboardAmbientWildlifeStage.height,
        );
        expect(tester.getSize(stage).width, width);
        final ignorePointers = find
            .ancestor(of: stage, matching: find.byType(IgnorePointer))
            .evaluate()
            .map((element) => element.widget as IgnorePointer);
        expect(ignorePointers.any((widget) => widget.ignoring), isTrue);
        expect(
          find.byKey(const ValueKey('dashboard-ambient-wildlife-idle')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'scheduler stays idle before its bounded interval and plans a day event once',
    (tester) async {
      await tester.pumpWidget(
        subject(
          now: () => DateTime(2026, 9, 19, 6),
          nextInt: (_) => 0,
          minimumInterval: const Duration(seconds: 45),
          maximumInterval: const Duration(seconds: 45),
        ),
      );
      await tester.pump(const Duration(seconds: 44));
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-idle')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-cat')),
        findsOneWidget,
      );
      final painter = painterFor(tester);
      expect(painter.plan?.kind, WildlifeKind.cat);
      expect(painter.plan?.count, 1);
      expect(painter.plan?.leftToRight, isTrue);
    },
  );

  testWidgets(
    'each completed event reevaluates local time before selecting the next pool',
    (tester) async {
      var localTime = DateTime(2026, 9, 19, 17, 59);
      await tester.pumpWidget(
        subject(
          now: () => localTime,
          nextInt: (_) => 0,
          minimumInterval: const Duration(milliseconds: 1),
          maximumInterval: const Duration(milliseconds: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-cat')),
        findsOneWidget,
      );
      localTime = DateTime(2026, 9, 19, 18);
      await tester.pump(const Duration(milliseconds: 3250));
      await tester.pump(const Duration(milliseconds: 2));
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-fox')),
        findsOneWidget,
      );
    },
  );

  test('V2 pose samples are deterministic, normalized, and wrap cleanly', () {
    for (final kind in WildlifeKind.values) {
      final first = wildlifePoseFor(kind, .37);
      final repeated = wildlifePoseFor(kind, .37);
      final wrapped = wildlifePoseFor(kind, 1.37);
      expect(repeated.bodyLength, first.bodyLength);
      expect(wrapped.bodyLength, closeTo(first.bodyLength, .000001));
      for (final value in [
        first.bodyLength,
        first.bodyHeight,
        first.bodyLift,
        first.foreReach,
        first.hindReach,
        first.tailLength,
        first.wingSpan,
        first.wingUp,
        first.wingDown,
      ]) {
        expect(value.isFinite, isTrue);
        expect(value.abs(), lessThan(3));
      }
    }
  });

  test('CAT V2 poses compress, extend, fly, and change limbs and tail', () {
    final gather = wildlifePoseFor(WildlifeKind.cat, 1 / 6);
    final flight = wildlifePoseFor(WildlifeKind.cat, 3 / 6);
    final reach = wildlifePoseFor(WildlifeKind.cat, 4 / 6);
    expect(gather.bodyLength, lessThan(flight.bodyLength));
    expect(flight.isFlight, isTrue);
    expect(flight.foreLift, greaterThan(0));
    expect(flight.hindLift, greaterThan(0));
    expect(gather.hindReach, isNot(flight.hindReach));
    expect(flight.foreReach, greaterThan(gather.foreReach));
    expect(reach.tailLift, isNot(gather.tailLift));
  });

  test(
    'FOX V2 gallop is distinct from CAT with stronger extension and tail',
    () {
      final foxGather = wildlifePoseFor(WildlifeKind.fox, 1 / 6);
      final foxFlight = wildlifePoseFor(WildlifeKind.fox, 3 / 6);
      final catGather = wildlifePoseFor(WildlifeKind.cat, 1 / 6);
      final catFlight = wildlifePoseFor(WildlifeKind.cat, 3 / 6);
      expect(
        foxFlight.bodyLength - foxGather.bodyLength,
        greaterThan(catFlight.bodyLength - catGather.bodyLength),
      );
      expect(foxFlight.muzzleLength, greaterThan(0));
      expect(foxFlight.tailThickness, greaterThan(catFlight.tailThickness));
      expect(foxFlight.isFlight, isTrue);
    },
  );

  test('BIRD and BAT use distinct whole-wing key-pose cycles', () {
    final birdUp = wildlifePoseFor(WildlifeKind.birds, 0);
    final birdLevel = wildlifePoseFor(WildlifeKind.birds, 2 / 6);
    final birdDown = wildlifePoseFor(WildlifeKind.birds, 3 / 6);
    final batFolded = wildlifePoseFor(WildlifeKind.bat, 0);
    final batExtended = wildlifePoseFor(WildlifeKind.bat, 2 / 6);
    expect(birdUp.wingUp, greaterThan(birdLevel.wingUp));
    expect(birdLevel.wingSpan, greaterThan(birdUp.wingSpan));
    expect(birdDown.wingDown, greaterThan(birdLevel.wingDown));
    expect(batExtended.wingSpan, greaterThan(batFolded.wingSpan));
    expect(batFolded.wingFold, greaterThan(birdUp.wingFold));
    expect(
      wildlifeCycleFrequencyFor(WildlifeKind.bat),
      greaterThan(wildlifeCycleFrequencyFor(WildlifeKind.birds)),
    );
  });

  test('gait and flap cycle counts are independent from travel width', () {
    for (final kind in WildlifeKind.values) {
      final plan = wildlifePreviewPlan(kind: kind, leftToRight: true);
      expect(wildlifeCycleCountForTraversal(plan, 320), greaterThan(4));
      expect(wildlifeCycleCountForTraversal(plan, 390), greaterThan(4));
      expect(wildlifeCycleCountForTraversal(plan, 900), greaterThan(4));
    }
  });

  testWidgets('day and night flock plans use bounded programmatic counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        now: () => DateTime(2026, 9, 19, 9),
        nextInt: (max) => max - 1,
        minimumInterval: const Duration(milliseconds: 1),
        maximumInterval: const Duration(milliseconds: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    final birds =
        tester
                .widget<CustomPaint>(
                  find.byKey(
                    const ValueKey('dashboard-ambient-wildlife-birds'),
                  ),
                )
                .painter!
            as DashboardAmbientWildlifePainter;
    expect(birds.plan?.count, 4);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      subject(
        now: () => DateTime(2026, 9, 19, 21),
        nextInt: (max) => max - 1,
        minimumInterval: const Duration(milliseconds: 1),
        maximumInterval: const Duration(milliseconds: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    final bats =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('dashboard-ambient-wildlife-bat')),
                )
                .painter!
            as DashboardAmbientWildlifePainter;
    expect(bats.plan?.count, 3);
  });

  testWidgets(
    'reduced motion renders the empty stage and never starts a timer event',
    (tester) async {
      await tester.pumpWidget(
        subject(
          reducedMotion: true,
          minimumInterval: Duration.zero,
          maximumInterval: Duration.zero,
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-idle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-cat')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-birds')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-fox')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-bat')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'disposing an active stage safely cancels its event controller and timer',
    (tester) async {
      await tester.pumpWidget(
        subject(
          now: () => DateTime(2026, 9, 19, 9),
          nextInt: (_) => 0,
          minimumInterval: const Duration(milliseconds: 1),
          maximumInterval: const Duration(milliseconds: 1),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.byKey(const ValueKey('dashboard-ambient-wildlife-cat')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    },
  );
}
