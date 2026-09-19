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

  test('uses a distinct outer-bowl D without an internal cross segment', () {
    final d = FoodVfdGlyphGeometry.activeSegmentsFor('D');
    final o = FoodVfdGlyphGeometry.activeSegmentsFor('O');

    expect(d, containsAll(['f', 'e', 'dTopOuterCorner', 'dRightStem']));
    expect(d, isNot(contains('g')));
    expect(d, isNot(contains('b')));
    expect(d, isNot(contains('c')));
    expect(d, isNot(equals(o)));
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

Widget _app({bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: const Scaffold(appBar: _FoodAppBar(), body: SizedBox.expand()),
  ),
);

class _FoodAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FoodAppBar();

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
    title: const FoodVfdScaleDisplayTitle(),
    actions: [
      IconButton(
        key: const ValueKey('food-vfd-action'),
        onPressed: () {},
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}
