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
    expect(draft.nameCandidates, containsAll(['香ばしいおいしさ', '明太子味']));
  });

  test('offers realistic package-front text as review candidates', () {
    final draft = parser.parse('''
OR FOODS
ザクザクポテト
ハッピーターン味
とまらないおいしさ
内容量 70g
OR食品株式会社
東京都千代田区1-2-3
開封後はお早めにお召し上がりください
''');

    expect(draft.name, isNull);
    expect(draft.brand, isNull);
    expect(draft.nameCandidates, contains('ザクザクポテト'));
    expect(draft.nameCandidates, contains('ハッピーターン味'));
    expect(draft.nameCandidates, isNot(contains('東京都千代田区1-2-3')));
    expect(draft.nameCandidates, isNot(contains('OR食品株式会社')));
    expect(draft.brandCandidates, containsAll(['OR FOODS', 'OR食品株式会社']));
    expect(draft.packageQuantity, 70);
    expect(draft.packageUnit, FoodQuantityUnit.gram);
  });

  test('conflicting labeled candidates remain unavailable', () {
    final draft = parser.parse('商品名：A\n商品名：B\n内容量 100g');
    expect(draft.name, isNull);
    expect(draft.packageQuantity, 100);
  });
}
