import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/engine/food_summary.dart';
import 'package:or_app/features/food/widgets/food_summary_card.dart';

void main() {
  const summary = FoodSummary(
    calories: 162,
    protein: 3.9,
    fat: 1.3,
    carbohydrates: 34.8,
    hydrationMl: 1200,
    mealCount: 1,
  );

  Widget app() => MaterialApp(
    theme: ThemeData(
      textTheme: const TextTheme(
        titleMedium: TextStyle(fontSize: 17),
        bodyMedium: TextStyle(fontSize: 13),
      ),
    ),
    home: const Scaffold(
      body: SingleChildScrollView(child: FoodSummaryCard(summary: summary)),
    ),
  );

  List<TextSpan> spans(WidgetTester tester, Key key) =>
      (tester
                  .widget<Text>(
                    find.descendant(
                      of: find.byKey(key),
                      matching: find.byType(Text),
                    ),
                  )
                  .textSpan!
              as TextSpan)
          .children!
          .cast<TextSpan>();

  testWidgets('all values use title font size minus one while units stay put', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    final titleFontSize = Theme.of(
      tester.element(find.byType(FoodSummaryCard)),
    ).textTheme.titleMedium!.fontSize!;

    for (final key in const [
      ValueKey('food-summary-calories-value'),
      ValueKey('food-summary-protein-value'),
      ValueKey('food-summary-fat-value'),
      ValueKey('food-summary-carbohydrate-value'),
      ValueKey('food-summary-water-value'),
    ]) {
      final valueSpans = spans(tester, key);
      expect(valueSpans.first.style?.fontSize, titleFontSize - 1);
      expect(valueSpans.last.style, isNull);
    }

    expect(
      spans(tester, const ValueKey('food-summary-calories-value')).first.text,
      '162',
    );
    expect(
      spans(tester, const ValueKey('food-summary-protein-value')).first.text,
      '3.9',
    );
    expect(
      spans(tester, const ValueKey('food-summary-fat-value')).first.text,
      '1.3',
    );
    expect(
      spans(
        tester,
        const ValueKey('food-summary-carbohydrate-value'),
      ).first.text,
      '34.8',
    );
    expect(
      spans(tester, const ValueKey('food-summary-water-value')).first.text,
      '1200',
    );
    expect(tester.widget<Text>(find.text('Calories')).style, isNull);
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('summary stays aligned at ${width.toInt()}dp', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app());

      expect(find.text('Carbohydrate'), findsOneWidget);
      expect(
        spans(
          tester,
          const ValueKey('food-summary-carbohydrate-value'),
        ).first.text,
        '34.8',
      );
      expect(
        spans(tester, const ValueKey('food-summary-water-value')).first.text,
        '1200',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
