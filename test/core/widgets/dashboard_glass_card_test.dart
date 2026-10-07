import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/theme/app_radius.dart';
import 'package:or_app/core/widgets/dashboard_glass_card.dart';
import 'package:or_app/core/widgets/operation_card.dart';

void main() {
  testWidgets('keeps the Dashboard production glass baseline', (tester) async {
    final theme = ThemeData.dark(useMaterial3: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: DashboardGlassCard(child: SizedBox(height: 40)),
        ),
      ),
    );

    final card = tester.widget<OperationCard>(find.byType(OperationCard));
    expect(card.padding, EdgeInsets.zero);
    final materialCard = tester.widget<Card>(find.byType(Card));
    expect(materialCard.color, Colors.transparent);
    expect(materialCard.surfaceTintColor, isNull);
    expect(materialCard.elevation, 6);
    final surface = tester.widget<Container>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).gradient != null,
      ),
    );
    final decoration = surface.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    final scheme = theme.colorScheme;

    expect(gradient.begin, Alignment.topLeft);
    expect(gradient.end, Alignment.bottomRight);
    expect(gradient.colors[0], scheme.primary.withValues(alpha: .085));
    expect(gradient.colors[1], scheme.surface.withValues(alpha: .24));
    expect(
      gradient.colors[2],
      scheme.surfaceContainerHigh.withValues(alpha: .13),
    );
    expect(
      (decoration.border! as Border).top.color,
      scheme.primary.withValues(alpha: .16),
    );
    expect(decoration.borderRadius, AppRadius.large);
    expect(decoration.boxShadow, hasLength(2));
    expect(
      decoration.boxShadow![0].color,
      scheme.primary.withValues(alpha: .055),
    );
    expect(decoration.boxShadow![0].blurRadius, 18);
    expect(decoration.boxShadow![0].offset, const Offset(-2, -2));
    expect(decoration.boxShadow![1].color, Colors.black.withValues(alpha: .34));
    expect(decoration.boxShadow![1].blurRadius, 18);
    expect(decoration.boxShadow![1].offset, const Offset(4, 8));
  });
}
