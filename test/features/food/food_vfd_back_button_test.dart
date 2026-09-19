import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_vfd_back_button.dart';
import 'package:or_app/features/food/widgets/food_vfd_scale_display_title.dart';

void main() {
  test('defines one 450ms triple right-to-left VFD scan response', () {
    expect(FoodVfdBackButton.exitDuration, const Duration(milliseconds: 450));
    expect(
      FoodVfdBackTiming.triangleExtinguishDuration,
      const Duration(milliseconds: 45),
    );
    expect(FoodVfdBackTiming.sweepDuration, const Duration(milliseconds: 115));
    expect(
      FoodVfdBackTiming.interSweepGapDuration,
      const Duration(milliseconds: 15),
    );

    final extinguish = _frameAt(20);
    final sweep1Start = _frameAt(45);
    final sweep1Middle = _frameAt(100);
    final sweep1End = _frameAt(159);
    final sweep2Start = _frameAt(175);
    final sweep3Start = _frameAt(305);
    final sweep3End = _frameAt(419);
    final afterglow = _frameAt(430);

    expect(extinguish.phase, FoodVfdBackPhase.extinguish);
    expect(extinguish.triangleOpacity, lessThan(1));
    expect(sweep1Start.sweepIndex, 0);
    expect(sweep1Start.scanPosition, closeTo(1, .001));
    expect(sweep1Middle.scanPosition, lessThan(sweep1Start.scanPosition));
    expect(sweep1End.scanPosition, lessThan(sweep1Middle.scanPosition));
    expect(sweep2Start.sweepIndex, 1);
    expect(sweep3Start.sweepIndex, 2);
    expect(sweep3End.scanPosition, lessThan(.02));
    expect(afterglow.phase, FoodVfdBackPhase.afterglow);
    expect(afterglow.hasTriangle, isFalse);
    expect(afterglow.hasAfterglow, isTrue);
  });

  testWidgets('renders a VFD triangle with normal Back semantics', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _FoodBackPage()));

    expect(find.byKey(const ValueKey('food-vfd-back')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food-vfd-back-triangle')),
      findsOneWidget,
    );
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(
      FoodVfdScaleDisplayTitle.activeEmissionColor,
      const Color(0xFF78E9D5),
    );
  });

  testWidgets('extinguishes then scans right-to-left exactly three times', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openBackRoute(tester);

    await tester.tap(find.byKey(const ValueKey('food-vfd-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(find.byKey(const ValueKey('food-vfd-back-sweep-1')), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const ValueKey('food-vfd-back-sweep-1')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.byKey(const ValueKey('food-vfd-back-sweep-2')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.byKey(const ValueKey('food-vfd-back-sweep-3')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      find.byKey(const ValueKey('food-vfd-back-afterglow')),
      findsOneWidget,
    );
    expect(find.text('FOOD PAGE'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('OPEN'), findsOneWidget);
    expect(find.text('FOOD PAGE'), findsNothing);
  });

  testWidgets('guards duplicate taps and safely disposes during a scan', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openBackRoute(tester);

    await tester.tap(find.byKey(const ValueKey('food-vfd-back')));
    await tester.tap(find.byKey(const ValueKey('food-vfd-back')));
    await tester.pump();
    await tester.pump(FoodVfdBackButton.exitDuration);
    await tester.pumpAndSettle();
    expect(find.text('OPEN'), findsOneWidget);

    await _openBackRoute(tester);
    await tester.tap(find.byKey(const ValueKey('food-vfd-back')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced Motion pops immediately without VFD scan motion', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await _openBackRoute(tester);

    await tester.tap(find.byKey(const ValueKey('food-vfd-back')));
    await tester.pumpAndSettle();

    expect(find.text('OPEN'), findsOneWidget);
    expect(find.byKey(const ValueKey('food-vfd-back-sweep-1')), findsNothing);
  });

  for (final width in [320.0, 390.0, 900.0]) {
    testWidgets('VFD Back keeps FOOD title clear at ${width.toInt()}px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: _FoodBackPage()));

      final back = tester.getRect(find.byKey(const ValueKey('food-vfd-back')));
      final title = tester.getRect(
        find.byKey(const ValueKey('food-vfd-scale-title')),
      );
      expect(back.width, 56);
      expect(title.center.dx, closeTo(width / 2, .5));
      expect(title.left, greaterThan(back.right));
      expect(tester.takeException(), isNull);
    });
  }
}

FoodVfdBackFrame _frameAt(int milliseconds) => FoodVfdBackTiming.frameFor(
  milliseconds / FoodVfdBackTiming.totalDuration.inMilliseconds,
);

class _FoodBackPage extends StatelessWidget {
  const _FoodBackPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      centerTitle: true,
      leading: const FoodVfdBackButton(),
      title: const FoodVfdScaleDisplayTitle(),
    ),
    body: const Center(child: Text('FOOD PAGE')),
  );
}

Widget _app({bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const _FoodBackPage()),
            ),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _openBackRoute(WidgetTester tester) async {
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  expect(find.text('FOOD PAGE'), findsOneWidget);
}
