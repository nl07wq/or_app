import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/morning/widgets/status_crt_back_button.dart';
import 'package:or_app/features/morning/widgets/status_crt_monitor_title.dart';

void main() {
  testWidgets('renders standard Back semantics with CRT phosphor treatment', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openStatusRoute(tester);

    expect(find.byKey(const ValueKey('status-crt-back')), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNWidgets(2));
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });

  testWidgets('Back runs one short exit response then pops once', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openStatusRoute(tester);

    await tester.tap(find.byKey(const ValueKey('status-crt-back')));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const ValueKey('status-crt-back-exit')), findsOneWidget);
    expect(find.text('STATUS PAGE'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('status-crt-back')));
    await tester.pump(StatusCrtBackButton.exitDuration);
    await tester.pumpAndSettle();
    expect(find.text('ROOT PAGE'), findsOneWidget);
    expect(find.text('STATUS PAGE'), findsNothing);
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
