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

  static const _knownLabels = [
    '栄養成分表示',
    'エネルギー',
    '熱量',
    'たんぱく質',
    'タンパク質',
    '蛋白質',
    '脂質',
    '炭水化物',
    '糖質',
    '食物繊維',
    '食塩相当量',
  ];

  NutritionOcrDraft parse(String rawText) {
    final text = _normalize(rawText);
    final table = _tableValues(text);
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
      calories: _value(text, const ['エネルギー', '熱量'], unit: 'kcal') ?? table?.$1,
      protein: _value(text, const ['たんぱく質', 'タンパク質', '蛋白質']) ?? table?.$2,
      fat: _value(text, const ['脂質']) ?? table?.$3,
      carbohydrate: _value(text, const ['炭水化物']) ?? table?.$4,
      packageQuantity: package?.$1,
      packageUnit: package?.$2,
    );
  }

  static String _normalize(String value) {
    var normalized = value
        .replaceAll('，', ',')
        .replaceAll('．', '.')
        .replaceAllMapped(RegExp(r'[０-９]'), (match) {
          final code = match.group(0)!.codeUnitAt(0) - 0xff10 + 0x30;
          return String.fromCharCode(code);
        })
        .replaceAllMapped(
          RegExp(r'(\d)[ \t\u3000]*[.,][ \t\u3000]*(\d)'),
          (match) => '${match.group(1)}.${match.group(2)}',
        );
    for (final label in _knownLabels) {
      final spacedLabel = label
          .split('')
          .map(RegExp.escape)
          .join(r'[ \t\u3000]*');
      normalized = normalized.replaceAll(RegExp(spacedLabel), label);
    }
    return normalized.replaceAll(RegExp(r'(?:[.・･·…⋯][ \t\u3000]*){2,}'), ' ');
  }

  static (double, double, double, double)? _tableValues(String text) {
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    const labels = [
      ['エネルギー', '熱量'],
      ['たんぱく質', 'タンパク質', '蛋白質'],
      ['脂質'],
      ['炭水化物'],
    ];
    var labelIndex = 0;
    var lastLabelLine = -1;
    for (
      var index = 0;
      index < lines.length && labelIndex < labels.length;
      index++
    ) {
      if (labels[labelIndex].any(lines[index].contains)) {
        labelIndex += 1;
        lastLabelLine = index;
      }
    }
    if (labelIndex != labels.length) return null;

    final values = <(double, String)>[];
    final pattern = RegExp(
      r'^[ \t\u3000|｜]*(\d+(?:\.\d+)?)[ \t\u3000]*(kcal|g)[ \t\u3000|｜]*$',
      caseSensitive: false,
    );
    for (final line in lines.skip(lastLabelLine + 1)) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!);
      if (value == null || !value.isFinite || value < 0) return null;
      values.add((value, match.group(2)!.toLowerCase()));
      if (values.length == 4) break;
    }
    if (values.length != 4 ||
        values[0].$2 != 'kcal' ||
        values.skip(1).any((value) => value.$2 != 'g')) {
      return null;
    }
    return (values[0].$1, values[1].$1, values[2].$1, values[3].$1);
  }

  static double? _value(
    String text,
    List<String> aliases, {
    String unit = 'g',
  }) {
    final names = aliases.map(RegExp.escape).join('|');
    final matches = RegExp(
      '(?:$names)(?:[ \\t\\u3000]*\\r?\\n[ \\t\\u3000]*|'
      '[ \\t\\u3000:：|｜\\-‐‑‒–—―]*)'
      '(\\d+(?:\\.\\d+)?)[ \\t\\u3000]*$unit(?![A-Za-z])',
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
