import '../food_nutrition_formatter.dart';
import '../models/food_quantity_models.dart';
import 'food_input_capture_gateway.dart';
import 'japanese_nutrition_ocr_parser.dart';

FoodOcrLiveCandidate describeNutritionCandidate(String rawText) =>
    FoodNutritionCandidateSession().describe(rawText);

class FoodNutritionCandidateSession {
  NutritionOcrDraft _draft = const NutritionOcrDraft();
  String? _lastRawText;

  NutritionOcrDraft get draft => _draft;
  String? get lastRawText => _lastRawText;

  FoodOcrLiveCandidate describe(String rawText) {
    _lastRawText = rawText;
    final next = const JapaneseNutritionOcrParser().parse(rawText);
    _draft = NutritionOcrDraft(
      basisQuantity: next.basisQuantity ?? _draft.basisQuantity,
      basisUnit: next.basisUnit ?? _draft.basisUnit,
      calories: next.calories ?? _draft.calories,
      protein: next.protein ?? _draft.protein,
      fat: next.fat ?? _draft.fat,
      carbohydrate: next.carbohydrate ?? _draft.carbohydrate,
      packageQuantity: next.packageQuantity ?? _draft.packageQuantity,
      packageUnit: next.packageUnit ?? _draft.packageUnit,
    );
    return _candidate(_draft, hasRawText: rawText.trim().isNotEmpty);
  }
}

FoodOcrLiveCandidate _candidate(
  NutritionOcrDraft draft, {
  required bool hasRawText,
}) {
  if (draft.isEmpty) {
    return FoodOcrLiveCandidate(
      state: hasRawText ? 'insufficient' : 'scanning',
      fields: const {},
    );
  }
  final hasMajorValues =
      draft.calories != null &&
      draft.protein != null &&
      draft.fat != null &&
      draft.carbohydrate != null;
  return FoodOcrLiveCandidate(
    state: hasMajorValues ? 'detected' : 'partial',
    fields: {
      'CALORIES': draft.calories == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.calories!)} kcal',
      'PROTEIN': draft.protein == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.protein!)} g',
      'FAT': draft.fat == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.fat!)} g',
      'CARBOHYDRATE': draft.carbohydrate == null
          ? null
          : '${FoodNutritionFormatter.amount(draft.carbohydrate!)} g',
      'BASIS': _quantity(draft.basisQuantity, draft.basisUnit),
      'PACKAGE': _quantity(draft.packageQuantity, draft.packageUnit),
    },
  );
}

String? _quantity(double? value, FoodQuantityUnit? unit) {
  if (value == null || unit == null) return null;
  final number = value == value.roundToDouble()
      ? value.round().toString()
      : FoodNutritionFormatter.macro(value);
  return '$number ${switch (unit) {
    FoodQuantityUnit.gram => 'g',
    FoodQuantityUnit.milliliter => 'mL',
    FoodQuantityUnit.piece => 'piece',
    FoodQuantityUnit.pack => 'pack',
    FoodQuantityUnit.serving => 'serving',
  }}';
}
