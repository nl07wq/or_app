import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/global_touch_ripple.dart';
import 'package:or_app/core/widgets/operation_button.dart';

void main() {
  testWidgets('maps semantic action roles to theme colors', (tester) async {
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              OperationButton(
                text: 'PRIMARY',
                role: OperationActionRole.primary,
                onPressed: () {},
              ),
              OperationButton(text: 'SECONDARY', onPressed: () {}),
              OperationButton(
                text: 'DANGER',
                role: OperationActionRole.danger,
                onPressed: () {},
              ),
              const OperationButton(text: 'DISABLED', onPressed: null),
            ],
          ),
        ),
      ),
    );

    Color? textColor(String label) =>
        tester.widget<Text>(find.text(label)).style?.color;

    expect(textColor('PRIMARY'), theme.colorScheme.primary);
    expect(textColor('SECONDARY'), Colors.white);
    expect(textColor('DANGER'), theme.colorScheme.error);
    expect(textColor('DISABLED'), theme.disabledColor);
  });

  testWidgets('can make a diagnostic button feedback-silent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationButton(
            text: 'DIAGNOSTIC',
            feedbackRole: ActionableFeedbackRole.silent,
            onPressed: () {},
          ),
        ),
      ),
    );

    final region = tester.widget<ActionableFeedbackRegion>(
      find.byType(ActionableFeedbackRegion),
    );
    expect(region.role, ActionableFeedbackRole.silent);
  });

  testWidgets('frosted operation button uses the WebKit-safe glass surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperationButton(
            text: 'FROSTED',
            frostedGradient: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('operation-safe-glass')), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ClipPath), findsNothing);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('FROSTED'), findsOneWidget);
    expect(tester.getSize(find.byType(ElevatedButton)), const Size(800, 52));
  });

  testWidgets('safe glass material renders its foreground pixels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(
          key: const ValueKey('safe-glass-golden'),
          child: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xff071522), Color(0xff23445a)],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: OperationButton(
                    text: 'OPERATION READY',
                    icon: Icons.play_arrow_rounded,
                    frostedGradient: true,
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey('safe-glass-golden')),
      matchesGoldenFile('goldens/operation_button_safe_glass.png'),
    );
  });
}
