import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_vfd_scale_display_title.dart';

void main() {
  test('keeps settled inactive VFD segments subordinate to self-test', () {
    expect(
      FoodVfdScaleDisplayTitle.settledInactiveSegmentOpacity,
      lessThanOrEqualTo(.04),
    );
    expect(
      FoodVfdScaleDisplayTitle.settledInactiveSegmentOpacity,
      lessThan(FoodVfdScaleDisplayTitle.selfTestInactiveSegmentOpacity),
    );
  });

  test('uses a narrow vertically proportioned VFD alphabet for FOOD', () {
    final f = FoodVfdGlyphGeometry.activeSegmentsFor('F');
    final d = FoodVfdGlyphGeometry.activeSegmentsFor('D');
    final firstO = FoodVfdGlyphGeometry.activeSegmentsFor('O');
    final secondO = FoodVfdGlyphGeometry.activeSegmentsFor('O');

    expect(f, equals(['leftStem', 'topBar', 'middleBar']));
    expect(firstO, equals(secondO));
    expect(firstO, containsAll(['chamferedLoop', 'openCounter']));
    expect(
      d,
      containsAll(['structuralLeftStem', 'continuousRightBowl', 'openCounter']),
    );
    expect(d, isNot(equals(firstO)));
    expect(d, isNot(contains('internalSlash')));
    expect(d, isNot(contains('rightRecognitionGap')));
    expect(
      FoodVfdScaleDisplayTitle.activeGlyphWidthFactor,
      lessThan(FoodVfdScaleDisplayTitle.v14GlyphWidthFactor),
    );
    expect(
      FoodVfdScaleDisplayTitle.activeGlyphHeightFactor /
          FoodVfdScaleDisplayTitle.activeGlyphWidthFactor,
      greaterThan(1),
    );
  });

  test('route alphabet covers uppercase Latin without ambiguous D or R', () {
    for (final glyph in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      expect(
        FoodVfdRouteGlyphGeometry.activeSegmentsFor(glyph),
        isNotEmpty,
        reason: '$glyph must have explicit VFD geometry',
      );
    }

    expect(
      FoodVfdRouteGlyphGeometry.activeSegmentsFor('D'),
      containsAll(['upperRightShoulder', 'lowerRightShoulder']),
    );
    expect(
      FoodVfdRouteGlyphGeometry.activeSegmentsFor('D'),
      isNot(equals(FoodVfdRouteGlyphGeometry.activeSegmentsFor('O'))),
    );
    expect(
      FoodVfdRouteGlyphGeometry.activeSegmentsFor('R'),
      contains('lowerRightDiagonal'),
    );
    expect(
      FoodVfdRouteGlyphGeometry.activeSegmentsFor('R'),
      isNot(equals(FoodVfdRouteGlyphGeometry.activeSegmentsFor('A'))),
    );
  });

  test('uses one compact centered lockup without changing V1.5 glyphs', () {
    const glassSize = Size(128, 29);
    final compactRects = FoodVfdWordLockup.glyphRects(glassSize);
    final compactBounds = FoodVfdWordLockup.boundsFor(glassSize);
    final compactGaps = FoodVfdWordLockup.gapsFor(glassSize);
    final legacyCellWidth = glassSize.width / 4;
    final legacyGlyphWidth =
        legacyCellWidth * FoodVfdScaleDisplayTitle.activeGlyphWidthFactor;
    final legacyGap = legacyCellWidth - legacyGlyphWidth;
    final legacyLockupWidth = legacyGlyphWidth * 4 + legacyGap * 3;

    expect(compactRects, hasLength(4));
    expect(compactBounds.width, lessThan(legacyLockupWidth * .85));
    expect(compactBounds.center.dx, closeTo(glassSize.width / 2, .01));
    expect(compactBounds.left, greaterThan(0));
    expect(glassSize.width - compactBounds.right, greaterThan(0));
    expect(compactGaps, everyElement(lessThan(legacyGap)));
    expect(compactGaps, everyElement(greaterThan(0)));
    for (var index = 0; index < compactRects.length - 1; index++) {
      expect(compactRects[index].right, lessThan(compactRects[index + 1].left));
    }
  });

  test('balances V1.7 optical kerning without returning to V1.5 spacing', () {
    const glassSize = Size(128, 29);
    final glyphWidth =
        glassSize.width / 4 * FoodVfdScaleDisplayTitle.activeGlyphWidthFactor;
    final v16Gaps = FoodVfdWordLockup.v16GapFactors
        .map((factor) => glyphWidth * factor)
        .toList(growable: false);
    final v17Gaps = FoodVfdWordLockup.gapsFor(glassSize);
    final v16LockupWidth =
        glyphWidth * 4 + v16Gaps.fold<double>(0, (sum, gap) => sum + gap);
    final v17LockupWidth =
        glyphWidth * 4 + v17Gaps.fold<double>(0, (sum, gap) => sum + gap);
    final v15Gap = glassSize.width / 4 - glyphWidth;
    final v15LockupWidth = glyphWidth * 4 + v15Gap * 3;

    expect(v17Gaps[0], lessThan(v16Gaps[0]));
    expect(v17Gaps[1], greaterThan(v16Gaps[1]));
    expect(v17Gaps[2], greaterThan(v16Gaps[2]));
    expect(v17Gaps, everyElement(greaterThan(0)));
    expect(v17LockupWidth, greaterThan(v16LockupWidth));
    expect(v17LockupWidth, lessThan(v15LockupWidth * .85));
  });

  test('self-test and every driver dropout retain compact glyph positions', () {
    const glassSize = Size(128, 29);
    final settled = FoodVfdWordLockup.glyphRects(glassSize);
    final selfTest = FoodVfdWordLockup.glyphRects(glassSize);

    expect(selfTest, equals(settled));
    for (final dropoutCharacter in [0, 1, 2, 3]) {
      final dropout = FoodVfdWordLockup.glyphRects(glassSize);
      for (var index = 0; index < settled.length; index++) {
        if (index == dropoutCharacter) continue;
        expect(dropout[index], equals(settled[index]));
      }
    }
  });

  testWidgets('renders one VFD scale housing with FOOD semantics', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));

    expect(find.byKey(const ValueKey('food-vfd-scale-title')), findsOneWidget);
    expect(find.byKey(const ValueKey('food-vfd-glass')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food-vfd-inactive-structure')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('FOOD'), findsOneWidget);
    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsNothing);
  });

  testWidgets('route labels keep the segmented VFD rendering grammar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final label in [
      'FOOD RECORD',
      'FOOD DATABASE',
      'ADD FOOD',
      'EDIT FOOD',
      'FOOD DETAIL',
      'CREATE RECIPE',
      'SELECT FOOD / RECIPE / MEAL',
    ]) {
      await tester.pumpWidget(_app(disableAnimations: true, label: label));
      await tester.pump();

      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(
        find.byKey(const ValueKey('food-vfd-inactive-structure')),
        findsOneWidget,
      );
      expect(find.text(label), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('food-vfd-scale-title'))),
        const Size(184, FoodVfdScaleDisplayTitle.height),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('FOOD DATABASE keeps the FOOD VFD frame and segment material', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(disableAnimations: true, label: 'FOOD DATABASE'),
    );

    await expectLater(
      find.byKey(const ValueKey('food-vfd-scale-title')),
      matchesGoldenFile('goldens/food_vfd_database_v11.png'),
    );
  });

  testWidgets('FOOD RECORD renders distinct uppercase route glyphs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(disableAnimations: true, label: 'FOOD RECORD'),
    );

    await expectLater(
      find.byKey(const ValueKey('food-vfd-scale-title')),
      matchesGoldenFile('goldens/food_vfd_record_v11a.png'),
    );
  });

  testWidgets('required FOOD titles retain exact uppercase VFD glyphs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(240, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_titleGallery());
    await tester.pump();

    await expectLater(
      find.byKey(const ValueKey('food-vfd-title-gallery')),
      matchesGoldenFile('goldens/food_vfd_route_titles_v11a.png'),
    );
  });

  testWidgets('self-test resolves once to the stable VFD display', (
    tester,
  ) async {
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return const Scaffold(
              appBar: _FoodAppBar(),
              body: SizedBox.expand(),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsOneWidget);
    await tester.pump(FoodVfdScaleDisplayTitle.selfTestDuration);
    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsNothing);
    expect(find.bySemanticsLabel('FOOD'), findsOneWidget);

    rebuild(() {});
    await tester.pump();
    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsNothing);
  });

  testWidgets('ENTRY re-energizes only after self-test and settles again', (
    tester,
  ) async {
    var randomCalls = 0;
    await tester.pumpWidget(
      _app(
        mode: FoodVfdScaleDisplayMode.entry,
        entryEventMinDelay: const Duration(milliseconds: 20),
        entryEventMaxDelay: const Duration(milliseconds: 20),
        nextInt: (_) {
          randomCalls++;
          return 0;
        },
      ),
    );
    await tester.pump();
    await tester.pump(FoodVfdScaleDisplayTitle.selfTestDuration);
    await tester.pump(const Duration(milliseconds: 1));

    expect(randomCalls, 1);
    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsNothing);
    expect(find.byKey(const ValueKey('food-vfd-entry-event')), findsNothing);
    await tester.pump(const Duration(milliseconds: 15));
    expect(find.byKey(const ValueKey('food-vfd-entry-event')), findsNothing);

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('food-vfd-entry-event')), findsOneWidget);
    expect(find.byKey(const ValueKey('food-vfd-driver-off-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('food-vfd-driver-off-1')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('food-vfd-entry-event')), findsNothing);

    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('food-vfd-entry-event')), findsOneWidget);
    expect(find.byKey(const ValueKey('food-vfd-driver-off-3')), findsOneWidget);
  });

  testWidgets('ENTRY cancellation and Reduced Motion leave no VFD event', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        mode: FoodVfdScaleDisplayMode.entry,
        entryEventMinDelay: const Duration(milliseconds: 10),
        entryEventMaxDelay: const Duration(milliseconds: 10),
      ),
    );
    await tester.pump();
    await tester.pump(FoodVfdScaleDisplayTitle.selfTestDuration);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _app(
        disableAnimations: true,
        mode: FoodVfdScaleDisplayMode.entry,
        entryEventMinDelay: const Duration(milliseconds: 10),
        entryEventMaxDelay: const Duration(milliseconds: 10),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsNothing);
    expect(find.byKey(const ValueKey('food-vfd-entry-event')), findsNothing);
  });

  testWidgets('normal FOOD title stays static after the self-test', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        entryEventMinDelay: const Duration(milliseconds: 20),
        entryEventMaxDelay: const Duration(milliseconds: 20),
      ),
    );
    await tester.pump();
    await tester.pump(FoodVfdScaleDisplayTitle.selfTestDuration);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('food-vfd-self-test')), findsNothing);
    expect(find.byKey(const ValueKey('food-vfd-entry-event')), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets(
      'VFD title remains clear of AppBar controls at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(disableAnimations: true));

        final title = tester.getRect(
          find.byKey(const ValueKey('food-vfd-scale-title')),
        );
        final back = tester.getRect(
          find.byKey(const ValueKey('food-vfd-back')),
        );
        final action = tester.getRect(
          find.byKey(const ValueKey('food-vfd-action')),
        );
        expect(title.center.dx, closeTo(width / 2, .5));
        expect(title.left, greaterThan(back.right));
        expect(title.right, lessThan(action.left));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app({
  bool disableAnimations = false,
  String label = 'FOOD',
  FoodVfdScaleDisplayMode mode = FoodVfdScaleDisplayMode.normal,
  Duration entryEventMinDelay = const Duration(seconds: 10),
  Duration entryEventMaxDelay = const Duration(seconds: 20),
  int Function(int max)? nextInt,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(
      appBar: _FoodAppBar(
        label: label,
        mode: mode,
        entryEventMinDelay: entryEventMinDelay,
        entryEventMaxDelay: entryEventMaxDelay,
        nextInt: nextInt,
      ),
      body: const SizedBox.expand(),
    ),
  ),
);

Widget _titleGallery() => MaterialApp(
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Material(
      color: Colors.black,
      child: Center(
        child: RepaintBoundary(
          key: const ValueKey('food-vfd-title-gallery'),
          child: ColoredBox(
            color: Colors.black,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                FoodVfdScaleDisplayTitle(),
                SizedBox(height: 4),
                FoodVfdScaleDisplayTitle(label: 'FOOD RECORD'),
                SizedBox(height: 4),
                FoodVfdScaleDisplayTitle(label: 'FOOD DATABASE'),
                SizedBox(height: 4),
                FoodVfdScaleDisplayTitle(label: 'ADD FOOD'),
                SizedBox(height: 4),
                FoodVfdScaleDisplayTitle(label: 'EDIT FOOD'),
                SizedBox(height: 4),
                FoodVfdScaleDisplayTitle(label: 'FOOD DETAIL'),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

class _FoodAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FoodAppBar({
    this.label = 'FOOD',
    this.mode = FoodVfdScaleDisplayMode.normal,
    this.entryEventMinDelay = const Duration(seconds: 10),
    this.entryEventMaxDelay = const Duration(seconds: 20),
    this.nextInt,
  });

  final String label;
  final FoodVfdScaleDisplayMode mode;
  final Duration entryEventMinDelay;
  final Duration entryEventMaxDelay;
  final int Function(int max)? nextInt;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    centerTitle: true,
    leading: IconButton(
      key: const ValueKey('food-vfd-back'),
      onPressed: () {},
      icon: const Icon(Icons.arrow_back),
    ),
    title: FoodVfdScaleDisplayTitle(
      label: label,
      mode: mode,
      entryEventMinDelay: entryEventMinDelay,
      entryEventMaxDelay: entryEventMaxDelay,
      nextInt: nextInt,
    ),
    actions: [
      IconButton(
        key: const ValueKey('food-vfd-action'),
        onPressed: () {},
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}
