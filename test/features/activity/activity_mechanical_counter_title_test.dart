import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/activity/widgets/activity_mechanical_counter_title.dart';

void main() {
  testWidgets('renders one mechanical housing with eight counter windows', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));

    expect(
      find.byKey(const ValueKey('activity-mechanical-counter-title')),
      findsOneWidget,
    );
    for (
      var index = 0;
      index < ActivityMechanicalCounterTitle.cellCount;
      index++
    ) {
      expect(
        find.byKey(ValueKey('activity-counter-cell-$index')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('activity-counter-character-$index')),
        findsOneWidget,
      );
    }
    expect(find.bySemanticsLabel('ACTIVITY'), findsOneWidget);
    expect(find.bySemanticsLabel('A'), findsNothing);
  });

  testWidgets('entry index settles once and does not restart on rebuild', (
    tester,
  ) async {
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return const Scaffold(
                appBar: _CounterAppBar(),
                body: SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('activity-counter-indexing-0')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 220));
    rebuild(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    for (
      var index = 0;
      index < ActivityMechanicalCounterTitle.cellCount;
      index++
    ) {
      expect(
        find.byKey(ValueKey('activity-counter-indexing-$index')),
        findsNothing,
      );
    }
  });

  testWidgets('reduced motion renders the settled counter immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('activity-counter-indexing-0')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('ACTIVITY'), findsOneWidget);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets(
      'counter remains centered and clear of actions at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(disableAnimations: true));

        final counter = tester.getRect(
          find.byKey(const ValueKey('activity-mechanical-counter-title')),
        );
        final back = tester.getRect(find.byKey(const ValueKey('counter-back')));
        final action = tester.getRect(
          find.byKey(const ValueKey('counter-action')),
        );
        expect(counter.center.dx, closeTo(width / 2, .5));
        expect(counter.left, greaterThan(back.right));
        expect(counter.right, lessThan(action.left));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app({required bool disableAnimations}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: const Scaffold(appBar: _CounterAppBar(), body: SizedBox.expand()),
  ),
);

class _CounterAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CounterAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    centerTitle: true,
    leading: IconButton(
      key: const ValueKey('counter-back'),
      onPressed: () {},
      icon: const Icon(Icons.arrow_back),
    ),
    title: const ActivityMechanicalCounterTitle(),
    actions: [
      IconButton(
        key: const ValueKey('counter-action'),
        onPressed: () {},
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}
