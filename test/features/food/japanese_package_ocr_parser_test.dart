import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/services/japanese_package_ocr_parser.dart';

void main() {
  const parser = JapanesePackageOcrParser();

  test('extracts only labeled name brand and evidenced package quantity', () {
    final draft = parser.parse('''
商品名：ひとくちソフトせんべい
ブランド：OR FOODS
内容量 １７０ｇ
香ばしいおいしさ
''');

    expect(draft.name, 'ひとくちソフトせんべい');
    expect(draft.brand, 'OR FOODS');
    expect(draft.packageQuantity, 170);
    expect(draft.packageUnit, FoodQuantityUnit.gram);
  });

  test('does not guess name or brand from unlabeled package copy', () {
    final draft = parser.parse('香ばしいおいしさ\n明太子味\n6個入');

    expect(draft.name, isNull);
    expect(draft.brand, isNull);
    expect(draft.packageQuantity, 6);
    expect(draft.packageUnit, FoodQuantityUnit.piece);
  });

  test('conflicting labeled candidates remain unavailable', () {
    final draft = parser.parse('商品名：A\n商品名：B\n内容量 100g');
    expect(draft.name, isNull);
    expect(draft.packageQuantity, 100);
  });
}
