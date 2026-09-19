import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/activity/widgets/activity_mechanical_back_button.dart';

void main() {
  testWidgets('renders a mechanical left-direction drum with Back semantics', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _MechanicalBackPage()));

    expect(
      find.byKey(const ValueKey('activity-mechanical-back-cell')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('activity-mechanical-back-symbol-left')),
      findsOneWidget,
    );
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
  });

  testWidgets('indexes through directions then locks left before one pop', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _openBackRoute(tester);

    await tester.tap(find.byKey(const ValueKey('activity-mechanical-back')));
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      find.byKey(const ValueKey('activity-mechanical-back-symbol-down')),
      findsWidgets,
    );
    expect(find.text('ROOT'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('activity-mechanical-back')));
    await tester.pump(const Duration(milliseconds: 270));
    expect(
      find.byKey(const ValueKey('activity-mechanical-back-symbol-left')),
      findsWidgets,
    );
    expect(find.text('ROOT'), findsNothing);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('reduced motion immediately uses normal Back navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await _openBackRoute(tester);

    await tester.tap(find.byKey(const ValueKey('activity-mechanical-back')));
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('keeps its standard hit target at 320, 390, and 900 pixels', (
    tester,
  ) async {
    for (final width in <double>[320, 390, 900]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(const MaterialApp(home: _MechanicalBackPage()));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('activity-mechanical-back')))
            .width,
        56,
      );
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

class _MechanicalBackPage extends StatelessWidget {
  const _MechanicalBackPage();

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(leading: const ActivityMechanicalBackButton()));
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
                  MaterialPageRoute(
                    builder: (_) => const _MechanicalBackPage(),
                  ),
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
