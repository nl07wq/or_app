import '../models/food_quantity_models.dart';
import '../models/nutrition_models.dart';

class FoodNutritionRecalculationPreview {
  const FoodNutritionRecalculationPreview({
    required this.packageQuantity,
    required this.packageUnit,
    required this.basisQuantity,
    required this.basisUnit,
    required this.current,
    required this.recalculated,
  });

  final double packageQuantity;
  final FoodQuantityUnit packageUnit;
  final double basisQuantity;
  final FoodQuantityUnit basisUnit;
  final NutritionSnapshot current;
  final NutritionSnapshot recalculated;
}

abstract final class FoodNutritionRecalculation {
  static String? blockedReason({
    required double? packageQuantity,
    required FoodQuantityUnit? packageUnit,
    required double? basisQuantity,
    required FoodQuantityUnit basisUnit,
    required NutritionSnapshot nutrition,
  }) {
    if (packageQuantity == null || packageUnit == null) {
      return 'SET PACKAGE QUANTITY AND UNIT';
    }
    if (!packageQuantity.isFinite || packageQuantity <= 0) {
      return 'PACKAGE QUANTITY MUST BE GREATER THAN ZERO';
    }
    if (basisQuantity == null ||
        !basisQuantity.isFinite ||
        basisQuantity <= 0) {
      return 'NUTRITION BASIS MUST BE GREATER THAN ZERO';
    }
    if (packageUnit != basisUnit) {
      return 'PACKAGE AND NUTRITION BASIS UNITS MUST MATCH';
    }
    if (nutrition.isEmpty) return 'ENTER AT LEAST ONE NUTRITION VALUE';
    return null;
  }

  static FoodNutritionRecalculationPreview preview({
    required double? packageQuantity,
    required FoodQuantityUnit? packageUnit,
    required double? basisQuantity,
    required FoodQuantityUnit basisUnit,
    required NutritionSnapshot nutrition,
  }) {
    final reason = blockedReason(
      packageQuantity: packageQuantity,
      packageUnit: packageUnit,
      basisQuantity: basisQuantity,
      basisUnit: basisUnit,
      nutrition: nutrition,
    );
    if (reason != null) throw StateError(reason);
    final factor = basisQuantity! / packageQuantity!;
    double? scaled(double? value) => value == null ? null : value * factor;
    return FoodNutritionRecalculationPreview(
      packageQuantity: packageQuantity,
      packageUnit: packageUnit!,
      basisQuantity: basisQuantity,
      basisUnit: basisUnit,
      current: nutrition,
      recalculated: NutritionSnapshot(
        calories: scaled(nutrition.calories),
        protein: scaled(nutrition.protein),
        fat: scaled(nutrition.fat),
        carbohydrate: scaled(nutrition.carbohydrate),
      ),
    );
  }
}

/// Localizes only the user-facing Manual nutrition validation layer. Domain
/// services retain their stable English reason codes for existing callers.
String foodManualNutritionValidationMessage(String reason) => switch (reason) {
  'SET PACKAGE QUANTITY AND UNIT' => '表示量と単位を入力してください',
  'PACKAGE QUANTITY MUST BE GREATER THAN ZERO' => '表示量は0より大きい値を入力してください',
  'NUTRITION BASIS MUST BE GREATER THAN ZERO' => '登録基準量は0より大きい値を入力してください',
  'PACKAGE AND NUTRITION BASIS UNITS MUST MATCH' => '表示量と登録基準量の単位を一致させてください',
  'ENTER AT LEAST ONE NUTRITION VALUE' => '栄養成分を1項目以上入力してください',
  'NUTRITION VALUES MUST BE ZERO OR GREATER.' => '栄養成分は0以上の値を入力してください',
  _ => reason,
};
