import 'package:flutter/material.dart';

import '../models/food_catalog_models.dart';

abstract final class FoodVisualIconResolver {
  static IconData resolve(
    FoodVisualKey? key, {
    IconData fallback = Icons.restaurant_menu,
  }) => switch (key) {
    FoodVisualKey.meat => Icons.kebab_dining_outlined,
    FoodVisualKey.fish => Icons.set_meal_outlined,
    FoodVisualKey.egg => Icons.egg_alt_outlined,
    FoodVisualKey.dairy => Icons.breakfast_dining_outlined,
    FoodVisualKey.grain => Icons.ramen_dining_outlined,
    FoodVisualKey.plate => Icons.lunch_dining_outlined,
    FoodVisualKey.vegetable => Icons.eco_outlined,
    FoodVisualKey.fruit => Icons.spa_outlined,
    FoodVisualKey.snack => Icons.cookie_outlined,
    FoodVisualKey.drink => Icons.local_drink_outlined,
    FoodVisualKey.condiment => Icons.soup_kitchen_outlined,
    FoodVisualKey.protein => Icons.fitness_center_outlined,
    FoodVisualKey.soup => Icons.soup_kitchen_outlined,
    FoodVisualKey.surimi => Icons.restaurant_menu,
    null => fallback,
  };

  static IconData resolveStableId(
    String? stableId, {
    IconData fallback = Icons.restaurant_menu,
  }) {
    if (stableId == null) return fallback;
    try {
      return resolve(FoodVisualKey.fromStableId(stableId), fallback: fallback);
    } on FormatException {
      return fallback;
    }
  }
}

abstract final class FoodThumbnailAssetResolver {
  static const _directory = 'assets/images/food_category';

  static String? resolve(FoodVisualKey? key) => switch (key) {
    FoodVisualKey.meat ||
    FoodVisualKey.fish ||
    FoodVisualKey.egg ||
    FoodVisualKey.dairy ||
    FoodVisualKey.grain ||
    FoodVisualKey.vegetable ||
    FoodVisualKey.fruit ||
    FoodVisualKey.protein ||
    FoodVisualKey.condiment ||
    FoodVisualKey.soup ||
    FoodVisualKey.surimi ||
    FoodVisualKey.plate => '$_directory/${key!.stableId}.png',
    _ => null,
  };
}

String foodVisualKeyLabel(FoodVisualKey key) => key.stableId.toUpperCase();

class FoodThumbnail extends StatelessWidget {
  const FoodThumbnail({
    super.key,
    required this.visualKey,
    this.size = 40,
    this.fallbackIcon = Icons.restaurant_menu,
  });

  final FoodVisualKey? visualKey;
  final double size;
  final IconData fallbackIcon;

  static const double _customAssetScale = 0.68;

  @override
  Widget build(BuildContext context) {
    final key = visualKey;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final asset = FoodThumbnailAssetResolver.resolve(key);
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: asset == null
            ? Icon(
                FoodVisualIconResolver.resolve(key, fallback: fallbackIcon),
                key: key == null
                    ? const ValueKey('food-thumbnail-fallback')
                    : ValueKey('food-thumbnail-${key.stableId}'),
                size: size * _customAssetScale,
                color: color,
              )
            : Center(
                child: SizedBox.square(
                  dimension: size * _customAssetScale,
                  child: Image.asset(
                    asset,
                    key: ValueKey('food-thumbnail-${key!.stableId}'),
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
      ),
    );
  }
}
