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

  testWidgets('normal index settles once and remains static after rebuild', (
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

    await tester.pump(const Duration(milliseconds: 550));
    rebuild(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    _expectNoMotion(tester);

    await tester.pump(const Duration(seconds: 1));
    _expectNoMotion(tester);
  });

  testWidgets('entry performs bounded periodic indexing only after settle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        mode: ActivityMechanicalCounterMode.entry,
        entryEventMinDelay: const Duration(milliseconds: 20),
        entryEventMaxDelay: const Duration(milliseconds: 20),
        nextInt: (_) => 0,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('activity-counter-indexing-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-counter-periodic-0')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 1150));
    _expectNoMotion(tester);
    await tester.pump(const Duration(milliseconds: 25));
    await tester.pump();

    final periodic = find.byKey(const ValueKey('activity-counter-periodic-0'));
    expect(periodic, findsOneWidget);
    expect(
      find
          .byKey(const ValueKey('activity-counter-periodic-1'))
          .evaluate()
          .length,
      lessThanOrEqualTo(1),
    );
    expect(find.bySemanticsLabel('ACTIVITY'), findsOneWidget);

    await tester.pump(ActivityMechanicalCounterTitle.periodicIndexDuration);
    _expectNoMotion(tester);
    expect(find.bySemanticsLabel('ACTIVITY'), findsOneWidget);
  });

  testWidgets('entry cancels pending periodic work when disposed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        mode: ActivityMechanicalCounterMode.entry,
        entryEventMinDelay: const Duration(milliseconds: 20),
        entryEventMaxDelay: const Duration(milliseconds: 20),
        nextInt: (_) => 0,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1150));
    await tester.pumpWidget(const SizedBox.expand());
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('activity-mechanical-counter-title')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps normal and entry titles static', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        disableAnimations: true,
        mode: ActivityMechanicalCounterMode.entry,
        entryEventMinDelay: Duration.zero,
        entryEventMaxDelay: Duration.zero,
        nextInt: (_) => 0,
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    _expectNoMotion(tester);
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

void _expectNoMotion(WidgetTester tester) {
  for (
    var index = 0;
    index < ActivityMechanicalCounterTitle.cellCount;
    index++
  ) {
    expect(
      find.byKey(ValueKey('activity-counter-indexing-$index')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('activity-counter-periodic-$index')),
      findsNothing,
    );
  }
}

Widget _app({
  bool disableAnimations = false,
  ActivityMechanicalCounterMode mode = ActivityMechanicalCounterMode.normal,
  Duration entryEventMinDelay = const Duration(seconds: 8),
  Duration entryEventMaxDelay = const Duration(seconds: 20),
  int Function(int max)? nextInt,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(
      appBar: _CounterAppBar(
        mode: mode,
        entryEventMinDelay: entryEventMinDelay,
        entryEventMaxDelay: entryEventMaxDelay,
        nextInt: nextInt,
      ),
      body: const SizedBox.expand(),
    ),
  ),
);

class _CounterAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CounterAppBar({
    this.mode = ActivityMechanicalCounterMode.normal,
    this.entryEventMinDelay = const Duration(seconds: 8),
    this.entryEventMaxDelay = const Duration(seconds: 20),
    this.nextInt,
  });

  final ActivityMechanicalCounterMode mode;
  final Duration entryEventMinDelay;
  final Duration entryEventMaxDelay;
  final int Function(int max)? nextInt;

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
    title: ActivityMechanicalCounterTitle(
      mode: mode,
      entryEventMinDelay: entryEventMinDelay,
      entryEventMaxDelay: entryEventMaxDelay,
      nextInt: nextInt,
    ),
    actions: [
      IconButton(
        key: const ValueKey('counter-action'),
        onPressed: () {},
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}
