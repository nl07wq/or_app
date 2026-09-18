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

    final phosphor = tester.widget<Text>(
      find.byKey(const ValueKey('status-crt-phosphor')),
    );
    final spans = (phosphor.textSpan! as TextSpan).children!.cast<TextSpan>();
    final status = spans.singleWhere((span) => span.text == 'STATUS');
    expect(status.style!.fontSize, 18);
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
    await tester.pumpWidget(
      _app(
        disableAnimations: true,
        mode: StatusCrtMonitorMode.entry,
        refreshMinDelay: Duration.zero,
        refreshMaxDelay: Duration.zero,
        nextInt: (_) => 0,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('> STATUS_'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-crt-boot-wake')), findsNothing);
    expect(find.byKey(const ValueKey('status-crt-retrace-line')), findsNothing);
  });

  testWidgets('ENTRY performs a bounded CRT retrace only after boot settles', (
    tester,
  ) async {
    var randomCalls = 0;
    await tester.pumpWidget(
      _app(
        mode: StatusCrtMonitorMode.entry,
        refreshMinDelay: const Duration(milliseconds: 20),
        refreshMaxDelay: const Duration(milliseconds: 20),
        nextInt: (_) {
          randomCalls++;
          return 0;
        },
      ),
    );
    await tester.pump();
    await tester.pump(StatusCrtMonitorTitle.bootDuration);
    await tester.pump(const Duration(milliseconds: 1));
    expect(randomCalls, 1);
    expect(find.byKey(const ValueKey('status-crt-retrace-line')), findsNothing);

    await tester.pump(const Duration(milliseconds: 25));
    expect(randomCalls, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('status-crt-retrace-line')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('STATUS'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('> STATUS_'), findsOneWidget);
    expect(find.byKey(const ValueKey('status-crt-retrace-line')), findsNothing);
  });

  testWidgets('ENTRY cancels scheduled CRT refresh when disposed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        mode: StatusCrtMonitorMode.entry,
        refreshMinDelay: const Duration(milliseconds: 20),
        refreshMaxDelay: const Duration(milliseconds: 20),
        nextInt: (_) => 0,
      ),
    );
    await tester.pump();
    await tester.pump(StatusCrtMonitorTitle.bootDuration);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpWidget(const SizedBox.expand());
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
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

Widget _app({
  bool disableAnimations = false,
  StatusCrtMonitorMode mode = StatusCrtMonitorMode.normal,
  Duration refreshMinDelay = const Duration(seconds: 10),
  Duration refreshMaxDelay = const Duration(seconds: 25),
  int Function(int max)? nextInt,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(
      appBar: _StatusAppBar(
        mode: mode,
        refreshMinDelay: refreshMinDelay,
        refreshMaxDelay: refreshMaxDelay,
        nextInt: nextInt,
      ),
      body: const SizedBox.expand(),
    ),
  ),
);

class _StatusAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatusAppBar({
    this.mode = StatusCrtMonitorMode.normal,
    this.refreshMinDelay = const Duration(seconds: 10),
    this.refreshMaxDelay = const Duration(seconds: 25),
    this.nextInt,
  });

  final StatusCrtMonitorMode mode;
  final Duration refreshMinDelay;
  final Duration refreshMaxDelay;
  final int Function(int max)? nextInt;

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
    title: StatusCrtMonitorTitle(
      mode: mode,
      refreshMinDelay: refreshMinDelay,
      refreshMaxDelay: refreshMaxDelay,
      nextInt: nextInt,
    ),
    actions: [
      IconButton(
        key: const ValueKey('status-action'),
        onPressed: () {},
        icon: const Icon(Icons.more_vert),
      ),
    ],
  );
}
