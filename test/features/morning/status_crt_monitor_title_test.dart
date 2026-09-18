import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/morning/widgets/status_crt_monitor_title.dart';

void main() {
  testWidgets('renders one physical CRT housing and STATUS semantics', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));

    expect(
      find.byKey(const ValueKey('status-crt-monitor-title')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('status-crt-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('status-crt-scanlines')), findsOneWidget);
    expect(find.bySemanticsLabel('STATUS'), findsOneWidget);
    expect(find.bySemanticsLabel('> STATUS_'), findsNothing);
  });

  testWidgets('boot wakes once then settles to the static terminal title', (
    tester,
  ) async {
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return const Scaffold(
              appBar: _StatusAppBar(),
              body: SizedBox.expand(),
            );
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('status-crt-boot-wake')), findsOneWidget);
    await tester.pump(StatusCrtMonitorTitle.bootDuration);
    expect(find.text('> STATUS_'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-crt-boot-wake')), findsNothing);

    rebuild(() {});
    await tester.pump();
    expect(find.text('> STATUS_'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-crt-boot-wake')), findsNothing);
  });

  testWidgets('reduced motion renders the settled CRT immediately', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));

    expect(find.text('> STATUS_'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-crt-boot-wake')), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets(
      'CRT title remains centered and clear of actions at ${width.toInt()}px',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_app(disableAnimations: true));

        final title = tester.getRect(
          find.byKey(const ValueKey('status-crt-monitor-title')),
        );
        final back = tester.getRect(find.byKey(const ValueKey('status-back')));
        final action = tester.getRect(
          find.byKey(const ValueKey('status-action')),
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
    child: const Scaffold(appBar: _StatusAppBar(), body: SizedBox.expand()),
  ),
);

class _StatusAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatusAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    centerTitle: true,
    leading: IconButton(
      key: const ValueKey('status-back'),
      onPressed: () {},
      icon: const Icon(Icons.arrow_back),
    ),
    title: const StatusCrtMonitorTitle(),
    actions: [
      IconButton(
        key: const ValueKey('status-action'),
        onPressed: () {},
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}
