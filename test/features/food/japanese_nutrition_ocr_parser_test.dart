import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/services/japanese_nutrition_ocr_parser.dart';

void main() {
  const parser = JapaneseNutritionOcrParser();

  const expectedRealLabel = (
    basis: 38.0,
    calories: 201.0,
    protein: 2.3,
    fat: 12.4,
    carbohydrate: 21.5,
  );

  void expectRealLabel(String rawText) {
    final draft = parser.parse(rawText);
    expect(draft.basisQuantity, expectedRealLabel.basis);
    expect(draft.basisUnit, FoodQuantityUnit.gram);
    expect(draft.calories, expectedRealLabel.calories);
    expect(draft.protein, expectedRealLabel.protein);
    expect(draft.fat, expectedRealLabel.fat);
    expect(draft.carbohydrate, expectedRealLabel.carbohydrate);
  }

  test('parses the clean real Japanese nutrition label', () {
    expectRealLabel('''
栄養成分表示：1袋38g当たり
エネルギー 201 kcal
たんぱく質 2.3 g
脂質 12.4 g
炭水化物 21.5 g
糖質 18.5 g
食物繊維 3.0 g
食塩相当量 0.4 g
''');
  });

  test('normalizes spaced labels and leader dots from a real package', () {
    expectRealLabel('''
栄 養 成 分 表 示：1袋38 g当たり
エ ネ ル ギ ー …… 201 kcal
た ん ぱ く 質 ･ ･ ･ 2.3 g
脂 質 ..... 12.4 g
炭 水 化 物 ····· 21.5 g
－ 糖 質 …… 18.5 g
－ 食 物 繊 維 …… 3.0 g
食 塩 相 当 量 …… 0.4 g
''');
  });

  test('maps separated real-label columns with explicit units', () {
    expectRealLabel('''
栄養成分表示：1袋38g当たり
エ ネ ル ギ ー
た ん ぱ く 質
脂 質
炭 水 化 物
201 kcal
2.3 g
12.4 g
21.5 g
''');
  });

  test('keeps carbohydrate distinct from sugar and dietary fiber', () {
    final draft = parser.parse('''
栄養成分表示 1袋38g当たり
糖質 18.5g
食物繊維 3.0g
炭水化物 …… 21.5g
''');

    expect(draft.carbohydrate, 21.5);
    expect(draft.carbohydrate, isNot(18.5));
    expect(draft.carbohydrate, isNot(3.0));
  });

  test('does not treat package content quantity as nutrition basis', () {
    final contentOnly = parser.parse('内容量 38g\nエネルギー 201kcal');
    expect(contentOnly.basisQuantity, isNull);
    expect(contentOnly.basisUnit, isNull);

    final nutritionContext = parser.parse('''
内容量 38g
栄養成分表示：1袋38g当たり
エネルギー 201kcal
''');
    expect(nutritionContext.basisQuantity, 38);
    expect(nutritionContext.basisUnit, FoodQuantityUnit.gram);
    expect(nutritionContext.packageQuantity, 38);
  });

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
