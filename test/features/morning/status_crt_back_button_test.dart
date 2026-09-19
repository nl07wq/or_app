import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/morning/widgets/status_crt_back_button.dart';
import 'package:or_app/features/morning/widgets/status_crt_monitor_title.dart';

void main() {
  testWidgets('renders a solid CRT triangle with standard Back semantics', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openStatusRoute(tester);

    expect(find.byKey(const ValueKey('status-crt-back')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('status-crt-back-triangle')),
      findsOneWidget,
    );
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });

  testWidgets('Back runs one short exit response then pops once', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openStatusRoute(tester);

    await tester.tap(find.byKey(const ValueKey('status-crt-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.byKey(const ValueKey('status-crt-back-exit')), findsOneWidget);
    final clip = tester.widget<ClipRect>(
      find.byKey(const ValueKey('status-crt-back-exit')),
    );
    final bounds = clip.clipper!.getClip(const Size(16, 18));
    expect(bounds.left, 0);
    expect(bounds.right, lessThan(16));
    expect(find.text('STATUS PAGE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('status-crt-back')));
    await tester.pump(StatusCrtBackButton.exitDuration);
    await tester.pumpAndSettle();
    expect(find.text('ROOT PAGE'), findsOneWidget);
    expect(find.text('STATUS PAGE'), findsNothing);
  });

  testWidgets('exit erases a fixed triangle from right to left', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: _StaticBackAppBar())),
    );

    final triangle = tester.getSize(
      find.byKey(const ValueKey('status-crt-back-triangle')),
    );
    await tester.tap(find.byKey(const ValueKey('status-crt-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final clip = tester.widget<ClipRect>(
      find.byKey(const ValueKey('status-crt-back-exit')),
    );
    final midway = clip.clipper!.getClip(triangle);
    expect(midway.left, 0);
    expect(midway.right, greaterThan(0));
    expect(midway.right, lessThan(triangle.width));
    expect(
      tester.getSize(find.byKey(const ValueKey('status-crt-back-triangle'))),
      triangle,
    );

    await tester.pump(StatusCrtBackButton.exitDuration);
    final finalClip = tester.widget<ClipRect>(
      find.byKey(const ValueKey('status-crt-back-exit')),
    );
    expect(finalClip.clipper!.getClip(triangle).width, 0);
  });

  testWidgets('Reduced Motion pops immediately without the exit motion', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await _openStatusRoute(tester);

    await tester.tap(find.byKey(const ValueKey('status-crt-back')));
    await tester.pumpAndSettle();

    expect(find.text('ROOT PAGE'), findsOneWidget);
    expect(find.text('STATUS PAGE'), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('CRT Back keeps STATUS title clear at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(disableAnimations: true));
      await _openStatusRoute(tester);

      final title = tester.getRect(
        find.byKey(const ValueKey('status-crt-monitor-title')),
      );
      final back = tester.getRect(
        find.byKey(const ValueKey('status-crt-back')),
      );
      expect(title.center.dx, closeTo(width / 2, .5));
      expect(title.left, greaterThan(back.right));
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _app({bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      disableAnimations: disableAnimations,
    ),
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ROOT PAGE'),
              FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const _StatusPage()),
                ),
                child: const Text('OPEN STATUS'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> _openStatusRoute(WidgetTester tester) async {
  await tester.tap(find.text('OPEN STATUS'));
  await tester.pumpAndSettle();
  expect(find.text('STATUS PAGE'), findsOneWidget);
}

class _StatusPage extends StatelessWidget {
  const _StatusPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      leading: const StatusCrtBackButton(),
      title: const StatusCrtMonitorTitle(),
    ),
    body: const Center(child: Text('STATUS PAGE')),
  );
}

class _StaticBackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StaticBackAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) =>
      AppBar(leading: const StatusCrtBackButton());
}
