import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/widgets/food_pfc_balance_card.dart';

void main() {
  for (final width in <double>[320, 375, 390, 430]) {
    testWidgets('contributors remain a 2x2 grid at ${width}dp', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: NutritionContributorGrid(
                children: const <Widget>[
                  _ContributorCell(key: ValueKey('calories'), text: 'CALORIES'),
                  _ContributorCell(key: ValueKey('protein'), text: 'PROTEIN'),
                  _ContributorCell(key: ValueKey('fat'), text: 'FAT'),
                  _ContributorCell(
                    key: ValueKey('carbohydrate'),
                    text: 'CARBOHYDRATE',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final calories = tester.getRect(find.byKey(const ValueKey('calories')));
      final protein = tester.getRect(find.byKey(const ValueKey('protein')));
      final fat = tester.getRect(find.byKey(const ValueKey('fat')));
      final carbohydrate = tester.getRect(
        find.byKey(const ValueKey('carbohydrate')),
      );
      expect(calories.top, closeTo(protein.top, .01));
      expect(fat.top, closeTo(carbohydrate.top, .01));
      expect(fat.top, greaterThan(calories.bottom));
      expect(calories.left, closeTo(fat.left, .01));
      expect(protein.left, closeTo(carbohydrate.left, .01));
      expect(calories.width, closeTo(protein.width, .01));
      expect(fat.width, closeTo(carbohydrate.width, .01));
      expect(tester.takeException(), isNull);
    });
  }
}

class _ContributorCell extends StatelessWidget {
  const _ContributorCell({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 96,
    child: DecoratedBox(
      decoration: BoxDecoration(border: Border.all()),
      child: Text(text, maxLines: 1),
    ),
  );
}
