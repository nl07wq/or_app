import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_colors.dart';
import 'package:or_app/features/training/widgets/training_dot_matrix_title.dart';
import 'package:or_app/features/training/widgets/training_led_back_button.dart';

void main() {
  test('widens only the LED triangle matrix rear/base', () {
    expect(TrainingLedBackGeometry.matrixColumns, 9);
    expect(TrainingLedBackGeometry.matrixRows, 7);
    expect(TrainingLedBackGeometry.activeColumns, 6);
    expect(TrainingLedBackGeometry.dotPitch, 2.4);
    expect(TrainingLedBackGeometry.dotRadius, .78);
    expect(TrainingLedBackGeometry.pattern, hasLength(7));
    expect(
      TrainingLedBackGeometry.pattern.every(
        (row) => row.length == TrainingLedBackGeometry.matrixColumns,
      ),
      isTrue,
    );
    expect(TrainingLedBackGeometry.pattern[3], '111111000');
  });

  testWidgets('renders a white LED triangle with standard Back semantics', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _BackPage()));

    expect(
      find.byKey(const ValueKey('training-led-back-triangle')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TrainingLedBackButton>(find.byType(TrainingLedBackButton))
          .activeColor,
      TrainingDotMatrixGeometry.normalActiveColor,
    );
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });

  testWidgets(
    'uses the Entry palette colors without changing its triangle geometry',
    (tester) async {
      for (final color in <Color>[
        AppColors.primary,
        AppColors.success,
        AppColors.warning,
      ]) {
        await tester.pumpWidget(MaterialApp(home: _BackPage(color: color)));
        expect(
          tester
              .widget<TrainingLedBackButton>(find.byType(TrainingLedBackButton))
              .activeColor,
          color,
        );
        expect(
          find.byKey(const ValueKey('training-led-back-triangle')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('scrolls the fixed LED dot pattern left before popping once', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openBackRoute(tester);

    await tester.tap(find.byKey(const ValueKey('training-led-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('training-led-back-scroll')),
    );
    expect(transform.transform.getTranslation().x, lessThan(0));

    await tester.tap(find.byKey(const ValueKey('training-led-back')));
    await tester.pump(TrainingLedBackButton.exitDuration);
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('reduced motion pops immediately without LED scroll-out', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await _openBackRoute(tester);

    await tester.tap(find.byKey(const ValueKey('training-led-back')));
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('fits the standard leading target at 320, 390, and 900 pixels', (
    tester,
  ) async {
    for (final width in <double>[320, 390, 900]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(const MaterialApp(home: _BackPage()));
      expect(
        tester.getSize(find.byKey(const ValueKey('training-led-back'))).width,
        56,
      );
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

class _BackPage extends StatelessWidget {
  const _BackPage({this.color = TrainingDotMatrixGeometry.normalActiveColor});

  final Color color;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: TrainingLedBackButton(activeColor: color)),
  );
}

Widget _app({bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ROOT'),
              FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const _BackPage()),
                ),
                child: const Text('OPEN'),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> _openBackRoute(WidgetTester tester) async {
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
}
