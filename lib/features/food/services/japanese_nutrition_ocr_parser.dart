import '../models/food_quantity_models.dart';

class NutritionOcrDraft {
  const NutritionOcrDraft({
    this.basisQuantity,
    this.basisUnit,
    this.calories,
    this.protein,
    this.fat,
    this.carbohydrate,
    this.packageQuantity,
    this.packageUnit,
  });

  final double? basisQuantity;
  final FoodQuantityUnit? basisUnit;
  final double? calories;
  final double? protein;
  final double? fat;
  final double? carbohydrate;
  final double? packageQuantity;
  final FoodQuantityUnit? packageUnit;

  bool get isEmpty =>
      basisQuantity == null &&
      calories == null &&
      protein == null &&
      fat == null &&
      carbohydrate == null &&
      packageQuantity == null;
}

class JapaneseNutritionOcrParser {
  const JapaneseNutritionOcrParser();

  NutritionOcrDraft parse(String rawText) {
    final text = _normalize(rawText);
    final basis = _quantity(
      text,
      RegExp(
        r'(\d+(?:\.\d+)?)\s*(g|ml|個|包装|袋|食)\s*[）)]?\s*(?:当たり|あたり)',
        caseSensitive: false,
      ),
    );
    final package = _quantity(
      text,
      RegExp(
        r'(?:内容量|NET(?:\s*WT)?)[\s:：]*(\d+(?:\.\d+)?)\s*(g|ml|個|包装|袋)',
        caseSensitive: false,
      ),
    );
    return NutritionOcrDraft(
      basisQuantity: basis?.$1,
      basisUnit: basis?.$2,
      calories: _value(text, const ['エネルギー', '熱量'], unit: 'kcal'),
      protein: _value(text, const ['たんぱく質', 'タンパク質', '蛋白質']),
      fat: _value(text, const ['脂質']),
      carbohydrate: _value(text, const ['炭水化物']),
      packageQuantity: package?.$1,
      packageUnit: package?.$2,
    );
  }

  static String _normalize(String value) => value
      .replaceAll('，', ',')
      .replaceAll('．', '.')
      .replaceAllMapped(RegExp(r'[０-９]'), (match) {
        final code = match.group(0)!.codeUnitAt(0) - 0xff10 + 0x30;
        return String.fromCharCode(code);
      });

  static double? _value(
    String text,
    List<String> aliases, {
    String unit = 'g',
  }) {
    final names = aliases.map(RegExp.escape).join('|');
    final matches = RegExp(
      '(?:$names)\\s*[:：]?\\s*(\\d+(?:\\.\\d+)?)\\s*$unit',
      caseSensitive: false,
    ).allMatches(text).toList(growable: false);
    if (matches.length != 1) return null;
    return double.tryParse(matches.single.group(1)!);
  }

  static (double, FoodQuantityUnit)? _quantity(String text, RegExp pattern) {
    final matches = pattern.allMatches(text).toList(growable: false);
    if (matches.length != 1) return null;
    final value = double.tryParse(matches.single.group(1)!);
    final unit = _unit(matches.single.group(2)!);
    if (value == null || value <= 0 || unit == null) return null;
    return (value, unit);
  }

  static FoodQuantityUnit? _unit(String value) => switch (value.toLowerCase()) {
    'g' => FoodQuantityUnit.gram,
    'ml' => FoodQuantityUnit.milliliter,
    '個' => FoodQuantityUnit.piece,
    '包装' || '袋' => FoodQuantityUnit.pack,
    '食' => FoodQuantityUnit.serving,
    _ => null,
  };
}
