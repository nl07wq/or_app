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

  testWidgets(
    'frosted gradient keeps foreground content outside tapered backdrop filters',
    (tester) async {
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

      expect(
        find.byKey(const ValueKey('operation-frosted-gradient')),
        findsOneWidget,
      );
      expect(find.byType(BackdropFilter), findsNWidgets(3));
      expect(find.byType(ClipPath), findsNWidgets(2));
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.text('FROSTED'), findsOneWidget);
    },
  );
}
