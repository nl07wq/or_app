import '../../../core/models/food_item.dart' as legacy;

import '../data/beta_meal_templates.dart';
import '../models/food_item.dart' as beta;
import '../models/meal_template.dart';

class BetaMealTemplateResolution {
  final List<legacy.FoodItem> items;
  final int skippedEntryCount;

  const BetaMealTemplateResolution({
    required this.items,
    required this.skippedEntryCount,
  });
}

class BetaMealTemplateResolver {
  const BetaMealTemplateResolver._();

  static BetaMealTemplateResolution resolve(MealTemplate template) {
    final items = <legacy.FoodItem>[];
    var skippedEntryCount = 0;

    for (final entry in template.entries) {
      switch (entry.referenceType) {
        case MealTemplateEntryReferenceType.foodItem:
          final foodItem = betaFoodItemsById[entry.referenceId];
          final resolved = foodItem == null
              ? null
              : _resolveFoodItem(foodItem, entry.amount, entry.unit);
          if (resolved == null) {
            skippedEntryCount++;
          } else {
            items.add(resolved);
          }
          break;
        case MealTemplateEntryReferenceType.recipe:
          final recipe = betaRecipesById[entry.referenceId];
          if (recipe == null || entry.unit != recipe.baseUnit) {
            skippedEntryCount++;
            break;
          }

          final multiplier = entry.amount / recipe.baseAmount;
          for (final ingredient in recipe.ingredients) {
            final foodItem = betaFoodItemsById[ingredient.foodItemId];
            final resolved = foodItem == null
                ? null
                : _resolveFoodItem(
                    foodItem,
                    ingredient.amount * multiplier,
                    ingredient.unit,
                  );
            if (resolved == null) {
              skippedEntryCount++;
            } else {
              items.add(resolved);
            }
          }
          break;
      }
    }

    return BetaMealTemplateResolution(
      items: List.unmodifiable(items),
      skippedEntryCount: skippedEntryCount,
    );
  }

  static legacy.FoodItem? _resolveFoodItem(
    beta.FoodItem foodItem,
    double amount,
    beta.FoodUnit unit,
  ) {
    if (unit != foodItem.baseUnit) {
      return null;
    }

    final nutrition = foodItem.nutritionForAmount(amount, unit);
    return legacy.FoodItem(
      name: '${foodItem.name} ${_formatAmount(amount, unit)}',
      calories: nutrition.calories.round(),
      protein: nutrition.protein,
      fat: nutrition.fat,
      carbohydrate: nutrition.carbs,
    );
  }

  static String _formatAmount(double amount, beta.FoodUnit unit) {
    final formattedAmount = amount == amount.roundToDouble()
        ? amount.round().toString()
        : amount.toString();
    return '$formattedAmount ${unit.name}';
  }
}
