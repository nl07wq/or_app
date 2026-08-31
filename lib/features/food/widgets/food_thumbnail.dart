import 'package:flutter/material.dart';

import '../models/food_catalog_models.dart';

abstract final class FoodVisualAssetResolver {
  static const _directory = 'assets/images/food_category';

  static String path(FoodVisualKey key) => switch (key) {
    FoodVisualKey.meat => '$_directory/meat.png',
    FoodVisualKey.fish => '$_directory/fish.png',
    FoodVisualKey.egg => '$_directory/egg.png',
    FoodVisualKey.dairy => '$_directory/dairy.png',
    FoodVisualKey.grain => '$_directory/grain.png',
    FoodVisualKey.vegetable => '$_directory/vegetable.png',
    FoodVisualKey.fruit => '$_directory/fruit.png',
    FoodVisualKey.snack => '$_directory/snack.png',
    FoodVisualKey.drink => '$_directory/drink.png',
    FoodVisualKey.condiment => '$_directory/condiment.png',
    FoodVisualKey.protein => '$_directory/protein.png',
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

  @override
  Widget build(BuildContext context) {
    final key = visualKey;
    return SizedBox.square(
      dimension: size,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: key == null
            ? _fallback(context)
            : Image.asset(
                FoodVisualAssetResolver.path(key),
                key: ValueKey('food-thumbnail-${key.stableId}'),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) => Icon(
    fallbackIcon,
    key: const ValueKey('food-thumbnail-fallback'),
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}
