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
        mode: mode,
        entryEventMinDelay: entryEventMinDelay,
        entryEventMaxDelay: entryEventMaxDelay,
        nextInt: nextInt,
      ),
      body: const SizedBox.expand(),
    ),
  ),
);

class _FoodAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FoodAppBar({
    this.mode = FoodVfdScaleDisplayMode.normal,
    this.entryEventMinDelay = const Duration(seconds: 10),
    this.entryEventMaxDelay = const Duration(seconds: 20),
    this.nextInt,
  });

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
