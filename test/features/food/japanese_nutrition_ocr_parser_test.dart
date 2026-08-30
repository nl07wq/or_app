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

  test('parses parenthesized serving weight used by compact labels', () {
    final draft = parser.parse('''
1食（2.0g）あたり
エネルギー
9.3kcal
たんぱく質
0.65g
脂質
0.51g
炭水化物
0.54g
食塩相当量
0.18g
''');

    expect(draft.basisQuantity, 2);
    expect(draft.basisUnit, FoodQuantityUnit.gram);
    expect(draft.calories, 9.3);
    expect(draft.protein, 0.65);
    expect(draft.fat, 0.51);
    expect(draft.carbohydrate, 0.54);
  });

  test('maps separated nutrition label and value sequences with units', () {
    final draft = parser.parse('''
エネルギー
たんぱく質
脂質
炭水化物
9.3kcal
0.65g
0.51g
0.54g
''');

    expect(draft.calories, 9.3);
    expect(draft.protein, 0.65);
    expect(draft.fat, 0.51);
    expect(draft.carbohydrate, 0.54);
  });

  test('does not map an unlabeled numeric sequence', () {
    final draft = parser.parse('9.3kcal\n0.65g\n0.51g\n0.54g');
    expect(draft.isEmpty, isTrue);
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
