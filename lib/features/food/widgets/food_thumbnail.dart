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
    FoodVisualKey.grain => Icons.rice_bowl_outlined,
    FoodVisualKey.vegetable => Icons.eco_outlined,
    FoodVisualKey.fruit => Icons.spa_outlined,
    FoodVisualKey.snack => Icons.cookie_outlined,
    FoodVisualKey.drink => Icons.local_drink_outlined,
    FoodVisualKey.condiment => Icons.soup_kitchen_outlined,
    FoodVisualKey.protein => Icons.fitness_center_outlined,
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

  static String? resolve(FoodVisualKey? key) =>
      key == null ? null : '$_directory/${key.stableId}.png';

  static String? resolveStableId(String? stableId) {
    if (stableId == null) return null;
    try {
      return resolve(FoodVisualKey.fromStableId(stableId));
    } on FormatException {
      return null;
    }
  }
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

  static const double _outerPadding = 3;
  static const double _symbolScale = 0.68;

  @override
  Widget build(BuildContext context) {
    final key = visualKey;
    final asset = FoodThumbnailAssetResolver.resolve(key);
    final thumbnailKey = key == null
        ? const ValueKey('food-thumbnail-fallback')
        : ValueKey('food-thumbnail-${key.stableId}');
    return SizedBox.square(
      key: key == null
          ? const ValueKey('food-thumbnail-box-fallback')
          : ValueKey('food-thumbnail-box-${key.stableId}'),
      dimension: size,
      child: Padding(
        padding: const EdgeInsets.all(_outerPadding),
        child: Center(
          child: SizedBox.square(
            dimension: size * _symbolScale,
            child: asset == null
                ? _fallbackIcon(context, thumbnailKey)
                : Image.asset(
                    asset,
                    key: thumbnailKey,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) =>
                        _fallbackIcon(context, thumbnailKey),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _fallbackIcon(BuildContext context, Key key) => Icon(
    FoodVisualIconResolver.resolve(visualKey, fallback: fallbackIcon),
    key: key,
    size: size * _symbolScale,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
