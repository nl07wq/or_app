enum FoodBaseUnit {
  g('g'),
  ml('mL');

  const FoodBaseUnit(this.label);

  final String label;

  static FoodBaseUnit parse(String source) {
    return switch (source) {
      'g' => FoodBaseUnit.g,
      'mL' || 'ml' => FoodBaseUnit.ml,
      _ => throw FormatException('Unsupported food base unit: $source.'),
    };
  }
}

enum FoodAmountMode {
  physicalAmount('physicalAmount'),
  baseMultiplier('baseMultiplier');

  const FoodAmountMode(this.serializedValue);

  final String serializedValue;

  static FoodAmountMode parse(String source) {
    return switch (source) {
      'physicalAmount' => FoodAmountMode.physicalAmount,
      'baseMultiplier' => FoodAmountMode.baseMultiplier,
      _ => throw FormatException('Unsupported food amount mode: $source.'),
    };
  }
}

class FoodItem {
  final String name;

  final num calories;

  final double protein;
  final double fat;
  final double carbohydrate;
  final int quantity;
  final double? amount;
  final double? baseAmount;
  final FoodBaseUnit? baseUnit;
  final FoodAmountMode? amountMode;

  const FoodItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbohydrate,
    int quantity = 1,
    this.amount,
    this.baseAmount,
    this.baseUnit,
    this.amountMode,
  }) : assert(calories >= 0),
       assert(protein >= 0),
       assert(fat >= 0),
       assert(carbohydrate >= 0),
       assert(
         (amount == null && baseAmount == null && baseUnit == null) ||
             (amount != null && baseAmount != null && baseUnit != null),
       ),
       assert(amount == null || amount > 0),
       assert(baseAmount == null || baseAmount > 0),
       assert(amountMode == null || amount != null),
       quantity = quantity < 1 ? 1 : quantity;

  bool get hasMeasuredAmount =>
      amount != null && baseAmount != null && baseUnit != null;

  FoodAmountMode get effectiveAmountMode =>
      amountMode ?? FoodAmountMode.physicalAmount;

  double get multiplier {
    if (!hasMeasuredAmount) return quantity.toDouble();
    return switch (effectiveAmountMode) {
      FoodAmountMode.physicalAmount => amount! / baseAmount!,
      FoodAmountMode.baseMultiplier => amount!,
    };
  }

  double? get physicalAmount {
    if (!hasMeasuredAmount) return null;
    return switch (effectiveAmountMode) {
      FoodAmountMode.physicalAmount => amount!,
      FoodAmountMode.baseMultiplier => baseAmount! * amount!,
    };
  }

  double get totalCalories => calories.toDouble() * multiplier;
  double get totalProtein => protein * multiplier;
  double get totalFat => fat * multiplier;
  double get totalCarbohydrate => carbohydrate * multiplier;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final quantity = (json['quantity'] as num?)?.toInt() ?? 1;
    final baseUnitValue = json['baseUnit'];
    final amountModeValue = json['amountMode'];
    final calories = json['calories'] as num;
    final protein = (json['protein'] as num).toDouble();
    final fat = (json['fat'] as num).toDouble();
    final carbohydrate = (json['carbohydrate'] as num).toDouble();
    final amount = (json['amount'] as num?)?.toDouble();
    final baseAmount = (json['baseAmount'] as num?)?.toDouble();
    final baseUnit = baseUnitValue == null
        ? null
        : FoodBaseUnit.parse(baseUnitValue as String);
    final amountMode = amountModeValue == null
        ? null
        : FoodAmountMode.parse(amountModeValue as String);
    _validateValues(
      calories: calories,
      protein: protein,
      fat: fat,
      carbohydrate: carbohydrate,
      amount: amount,
      baseAmount: baseAmount,
      baseUnit: baseUnit,
      amountMode: amountMode,
    );

    final item = FoodItem(
      name: json['name'] as String,
      calories: calories,
      protein: protein,
      fat: fat,
      carbohydrate: carbohydrate,
      quantity: quantity < 1 ? 1 : quantity,
      amount: amount,
      baseAmount: baseAmount,
      baseUnit: baseUnit,
      amountMode: amountMode,
    );
    item._validateCalculatedSnapshot(json);
    return item;
  }

  FoodItem copyWith({
    String? name,
    num? calories,
    double? protein,
    double? fat,
    double? carbohydrate,
    int? quantity,
    double? amount,
    double? baseAmount,
    FoodBaseUnit? baseUnit,
    FoodAmountMode? amountMode,
  }) {
    return FoodItem(
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbohydrate: carbohydrate ?? this.carbohydrate,
      quantity: quantity ?? this.quantity,
      amount: amount ?? this.amount,
      baseAmount: baseAmount ?? this.baseAmount,
      baseUnit: baseUnit ?? this.baseUnit,
      amountMode: amountMode ?? this.amountMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'calories': calories,
      'protein': protein,
      'fat': fat,
      'carbohydrate': carbohydrate,
      'quantity': quantity,
      if (amount != null) 'amount': amount,
      if (baseAmount != null) 'baseAmount': baseAmount,
      if (baseUnit != null) 'baseUnit': baseUnit!.label,
      if (amountMode != null) 'amountMode': amountMode!.serializedValue,
      if (hasMeasuredAmount) ...{
        'calculatedCalories': totalCalories,
        'calculatedProtein': totalProtein,
        'calculatedFat': totalFat,
        'calculatedCarbohydrate': totalCarbohydrate,
      },
    };
  }

  @override
  bool operator ==(Object other) {
    return other is FoodItem &&
        other.name == name &&
        other.calories == calories &&
        other.protein == protein &&
        other.fat == fat &&
        other.carbohydrate == carbohydrate &&
        other.quantity == quantity &&
        other.amount == amount &&
        other.baseAmount == baseAmount &&
        other.baseUnit == baseUnit &&
        other.amountMode == amountMode;
  }

  @override
  int get hashCode => Object.hash(
    name,
    calories,
    protein,
    fat,
    carbohydrate,
    quantity,
    amount,
    baseAmount,
    baseUnit,
    amountMode,
  );

  static void _validateValues({
    required num calories,
    required double protein,
    required double fat,
    required double carbohydrate,
    required double? amount,
    required double? baseAmount,
    required FoodBaseUnit? baseUnit,
    required FoodAmountMode? amountMode,
  }) {
    final values = [calories.toDouble(), protein, fat, carbohydrate];
    if (values.any((value) => !value.isFinite || value < 0)) {
      throw const FormatException('Nutrition must be finite and non-negative.');
    }
    final fields = [amount, baseAmount, baseUnit];
    final populated = fields.where((value) => value != null).length;
    if (populated != 0 && populated != fields.length) {
      throw const FormatException(
        'amount, baseAmount, and baseUnit must be provided together.',
      );
    }
    if (amountMode != null && populated != fields.length) {
      throw const FormatException(
        'amountMode requires amount, baseAmount, and baseUnit.',
      );
    }
    if (amount != null && (!amount.isFinite || amount <= 0)) {
      throw const FormatException(
        'Amount must be finite and greater than zero.',
      );
    }
    if (baseAmount != null && (!baseAmount.isFinite || baseAmount <= 0)) {
      throw const FormatException(
        'Base amount must be finite and greater than zero.',
      );
    }
  }

  void _validateCalculatedSnapshot(Map<String, dynamic> json) {
    if (!hasMeasuredAmount) return;
    final expected = <String, double>{
      'calculatedCalories': totalCalories,
      'calculatedProtein': totalProtein,
      'calculatedFat': totalFat,
      'calculatedCarbohydrate': totalCarbohydrate,
    };
    final populated = expected.keys.where(json.containsKey).length;
    if (populated == 0) return;
    if (populated != expected.length) {
      throw const FormatException(
        'Calculated FOOD nutrition Snapshot is incomplete.',
      );
    }
    for (final entry in expected.entries) {
      final stored = json[entry.key];
      if (stored is! num ||
          !stored.isFinite ||
          (stored.toDouble() - entry.value).abs() > 1e-9) {
        throw FormatException(
          'Calculated FOOD nutrition Snapshot does not match ${entry.key}.',
        );
      }
    }
  }
}
