import '../models/food_quantity_models.dart';

class PackageOcrDraft {
  const PackageOcrDraft({
    this.name,
    this.brand,
    this.packageQuantity,
    this.packageUnit,
    this.nameCandidates = const [],
    this.brandCandidates = const [],
  });

  final String? name;
  final String? brand;
  final double? packageQuantity;
  final FoodQuantityUnit? packageUnit;
  final List<String> nameCandidates;
  final List<String> brandCandidates;

  bool get isEmpty =>
      name == null &&
      brand == null &&
      packageQuantity == null &&
      packageUnit == null &&
      nameCandidates.isEmpty &&
      brandCandidates.isEmpty;
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
    final name = _labeledValue(lines, const ['商品名', '名称']);
    final brand = _labeledValue(lines, const ['ブランド', 'メーカー']);
    return PackageOcrDraft(
      name: name,
      brand: brand,
      packageQuantity: package?.$1,
      packageUnit: package?.$2,
      nameCandidates: _nameCandidates(lines, name),
      brandCandidates: _brandCandidates(lines, brand),
    );
  }

  static List<String> _nameCandidates(List<String> lines, String? labeled) {
    final values = <String>{?labeled};
    for (final source in lines) {
      final line = _candidateText(source);
      if (line == null || _isExcluded(line) || _isBrandLike(line)) continue;
      if (!RegExp(r'[ぁ-んァ-ヶ一-龠]').hasMatch(line)) continue;
      values.add(line);
      if (values.length >= 8) break;
    }
    return values.toList(growable: false);
  }

  static List<String> _brandCandidates(List<String> lines, String? labeled) {
    final values = <String>{?labeled};
    for (final source in lines) {
      final line = _candidateText(source);
      if (line == null || _isExcluded(line) || !_isBrandLike(line)) continue;
      values.add(line);
      if (values.length >= 6) break;
    }
    return values.toList(growable: false);
  }

  static String? _candidateText(String source) {
    final value = source.replaceFirst(RegExp(r'^[\s\-―ー・●■◆※]+'), '').trim();
    if (value.length < 2 || value.length > 40) return null;
    return value;
  }

  static bool _isExcluded(String value) => RegExp(
    r'^(?:商品名|名称|ブランド|メーカー|内容量|正味量|NET|原材料|栄養成分|保存方法|賞味期限|消費期限|注意|お問い合わせ|お問合せ|電話|TEL|製造所|販売者|製造者|住所|開封後|本品|お召し上がり|直射日光|高温多湿)|'
    r'〒\s*\d|(?:東京都|北海道|(?:大阪|京都)府|.{2,3}県).*(?:市|区|町|村)|'
    r'^\d+(?:\.\d+)?\s*(?:g|ml|個|袋|包装)(?:入)?$',
    caseSensitive: false,
  ).hasMatch(value);

  static bool _isBrandLike(String value) =>
      RegExp(r'(?:株式会社|有限会社|フーズ|食品|製菓)$').hasMatch(value) ||
      RegExp(r'^[A-Z][A-Z0-9 &.\-]{1,29}$').hasMatch(value);

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
