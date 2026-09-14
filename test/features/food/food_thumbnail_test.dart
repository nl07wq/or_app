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

  test('asset resolver maintains the visual key and unknown-key contracts', () {
    for (final key in FoodVisualKey.values) {
      expect(
        FoodThumbnailAssetResolver.resolve(key),
        'assets/images/food_category/${key.stableId}.png',
      );
      expect(
        FoodThumbnailAssetResolver.resolveStableId(key.stableId),
        'assets/images/food_category/${key.stableId}.png',
      );
    }
    expect(FoodThumbnailAssetResolver.resolve(null), isNull);
    expect(FoodThumbnailAssetResolver.resolveStableId('unsupported'), isNull);
  });

  testWidgets('all visual keys render normalized custom assets and null uses '
      'the Material fallback', (tester) async {
    for (final key in FoodVisualKey.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(child: FoodThumbnail(visualKey: key)),
          ),
        ),
      );
      final thumbnail = find.byKey(ValueKey('food-thumbnail-${key.stableId}'));
      final image = tester.widget<Image>(thumbnail);
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/food_category/${key.stableId}.png',
      );
      expect(tester.getSize(thumbnail).width, moreOrLessEquals(27.2));
      expect(tester.getSize(thumbnail).height, moreOrLessEquals(27.2));
      expect(
        tester
            .getSize(find.byKey(ValueKey('food-thumbnail-box-${key.stableId}')))
            .width,
        40,
      );
      expect(
        tester
            .widget<Padding>(
              find.ancestor(of: thumbnail, matching: find.byType(Padding)),
            )
            .padding,
        const EdgeInsets.all(3),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(child: FoodThumbnail(visualKey: null)),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('food-thumbnail-fallback')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('food-thumbnail-fallback')))
          .icon,
      Icons.restaurant_menu,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('food-thumbnail-fallback')))
          .width,
      moreOrLessEquals(27.2),
    );
  });

  testWidgets('SELECT THUMBNAIL uses the established 52px display box', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: FoodThumbnail(visualKey: FoodVisualKey.meat, size: 52),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('food-thumbnail-box-meat'))),
      const Size(52, 52),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('food-thumbnail-meat'))).width,
      moreOrLessEquals(35.36),
    );
  });
}
