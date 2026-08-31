import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/widgets/food_thumbnail.dart';

void main() {
  test('all visual keys resolve to the approved Material icon', () {
    expect(FoodVisualKey.values, hasLength(11));
    const expected = <FoodVisualKey, IconData>{
      FoodVisualKey.meat: Icons.kebab_dining_outlined,
      FoodVisualKey.fish: Icons.set_meal_outlined,
      FoodVisualKey.egg: Icons.egg_alt_outlined,
      FoodVisualKey.dairy: Icons.breakfast_dining_outlined,
      FoodVisualKey.grain: Icons.rice_bowl_outlined,
      FoodVisualKey.vegetable: Icons.eco_outlined,
      FoodVisualKey.fruit: Icons.spa_outlined,
      FoodVisualKey.snack: Icons.cookie_outlined,
      FoodVisualKey.drink: Icons.local_drink_outlined,
      FoodVisualKey.condiment: Icons.soup_kitchen_outlined,
      FoodVisualKey.protein: Icons.fitness_center_outlined,
    };
    for (final entry in expected.entries) {
      expect(FoodVisualIconResolver.resolve(entry.key), entry.value);
      expect(
        FoodVisualIconResolver.resolveStableId(entry.key.stableId),
        entry.value,
      );
      final key = entry.key;
      expect(foodVisualKeyLabel(key), key.stableId.toUpperCase());
    }
  });

  test('null and unknown stable IDs resolve to the generic fallback', () {
    expect(FoodVisualIconResolver.resolve(null), Icons.restaurant_menu);
    expect(
      FoodVisualIconResolver.resolveStableId('unsupported'),
      Icons.restaurant_menu,
    );
  });

  testWidgets('all visual keys render icons and null uses food fallback', (
    tester,
  ) async {
    for (final key in FoodVisualKey.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: FoodThumbnail(visualKey: key),
        ),
      );
      final icon = tester.widget<Icon>(
        find.byKey(ValueKey('food-thumbnail-${key.stableId}')),
      );
      expect(icon.icon, FoodVisualIconResolver.resolve(key));
      expect(find.byType(Image), findsNothing);
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const FoodThumbnail(visualKey: null),
      ),
    );
    expect(
      find.byKey(const ValueKey('food-thumbnail-fallback')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('food-thumbnail-fallback')),
          )
          .icon,
      Icons.restaurant_menu,
    );
  });
}
