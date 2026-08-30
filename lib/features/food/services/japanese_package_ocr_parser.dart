import '../models/food_quantity_models.dart';

class PackageOcrDraft {
  const PackageOcrDraft({
    this.name,
    this.brand,
    this.packageQuantity,
    this.packageUnit,
  });

  final String? name;
  final String? brand;
  final double? packageQuantity;
  final FoodQuantityUnit? packageUnit;

  bool get isEmpty =>
      name == null &&
      brand == null &&
      packageQuantity == null &&
      packageUnit == null;
}

class JapanesePackageOcrParser {
  const JapanesePackageOcrParser();

  PackageOcrDraft parse(String rawText) {
    final text = _normalize(rawText);
    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final package = _package(text);
    return PackageOcrDraft(
      name: _labeledValue(lines, const ['商品名', '名称']),
      brand: _labeledValue(lines, const ['ブランド', 'メーカー']),
      packageQuantity: package?.$1,
      packageUnit: package?.$2,
    );
  }

  static String? _labeledValue(List<String> lines, List<String> labels) {
    final names = labels.map(RegExp.escape).join('|');
    final pattern = RegExp('^(?:$names)\\s*[:：]\\s*(.+)\$');
    final values = <String>{};
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) values.add(value);
    }
    return values.length == 1 ? values.single : null;
  }

  static (double, FoodQuantityUnit)? _package(String text) {
    final patterns = [
      RegExp(
        r'(?:内容量|正味量|NET(?:\s*WT)?)\s*[:：]?\s*(\d+(?:\.\d+)?)\s*(g|ml|個|包装|袋)',
        caseSensitive: false,
      ),
      RegExp(r'(?<!\d)(\d+(?:\.\d+)?)\s*(個)\s*入'),
    ];
    final values = <(double, FoodQuantityUnit)>{};
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final value = double.tryParse(match.group(1)!);
        final unit = _unit(match.group(2)!);
        if (value != null && value.isFinite && value > 0 && unit != null) {
          values.add((value, unit));
        }
      }
    }
    return values.length == 1 ? values.single : null;
  }

  static String _normalize(String value) => value
      .replaceAll('，', ',')
      .replaceAll('．', '.')
      .replaceAll('ｇ', 'g')
      .replaceAll('ｍｌ', 'ml')
      .replaceAll('ｍＬ', 'mL')
      .replaceAllMapped(RegExp(r'[０-９]'), (match) {
        final code = match.group(0)!.codeUnitAt(0) - 0xff10 + 0x30;
        return String.fromCharCode(code);
      });

  static FoodQuantityUnit? _unit(String value) => switch (value.toLowerCase()) {
    'g' => FoodQuantityUnit.gram,
    'ml' => FoodQuantityUnit.milliliter,
    '個' => FoodQuantityUnit.piece,
    '包装' || '袋' => FoodQuantityUnit.pack,
    _ => null,
  };
}
