import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/services/japanese_nutrition_ocr_parser.dart';

void main() {
  const parser = JapaneseNutritionOcrParser();

  test('parses Japanese nutrition label and package without guessing', () {
    final draft = parser.parse('''
栄養成分表示 100g当たり
エネルギー 154kcal
たんぱく質 1.9g
脂質 5.5g
炭水化物 24.2g
内容量 500g
''');

    expect(draft.basisQuantity, 100);
    expect(draft.basisUnit, FoodQuantityUnit.gram);
    expect(draft.calories, 154);
    expect(draft.protein, 1.9);
    expect(draft.fat, 5.5);
    expect(draft.carbohydrate, 24.2);
    expect(draft.packageQuantity, 500);
    expect(draft.packageUnit, FoodQuantityUnit.gram);
  });

  for (final testCase in [
    ('100mLあたり', 100.0, FoodQuantityUnit.milliliter),
    ('1個当たり', 1.0, FoodQuantityUnit.piece),
    ('1包装あたり', 1.0, FoodQuantityUnit.pack),
    ('1袋当たり', 1.0, FoodQuantityUnit.pack),
    ('1食当たり', 1.0, FoodQuantityUnit.serving),
  ]) {
    test('parses basis ${testCase.$1}', () {
      final draft = parser.parse('${testCase.$1}\n熱量 42kcal');
      expect(draft.basisQuantity, testCase.$2);
      expect(draft.basisUnit, testCase.$3);
    });
  }

  test('supports nutrition aliases and full-width digits', () {
    final draft = parser.parse('''
１００ｇあたり
熱量 ５７．１kcal
タンパク質 ２．３g
脂質 １．２g
炭水化物 ８．４g
NET WT ３５g
''');
    expect(draft.calories, 57.1);
    expect(draft.protein, 2.3);
    expect(draft.packageQuantity, 35);
  });

  test('missing basis remains unavailable', () {
    final draft = parser.parse('エネルギー 154kcal');
    expect(draft.basisQuantity, isNull);
    expect(draft.basisUnit, isNull);
  });

  test('ambiguous duplicate values remain unavailable', () {
    final draft = parser.parse('エネルギー 154kcal\n熱量 155kcal');
    expect(draft.calories, isNull);
  });
}
