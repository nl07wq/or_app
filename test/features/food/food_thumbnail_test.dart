import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/widgets/food_thumbnail.dart';

void main() {
  const customAssets = <FoodVisualKey, String>{
    FoodVisualKey.meat: 'meat.png',
    FoodVisualKey.fish: 'fish.png',
    FoodVisualKey.dairy: 'dairy.png',
    FoodVisualKey.grain: 'grain.png',
    FoodVisualKey.vegetable: 'vegetable.png',
    FoodVisualKey.fruit: 'fruit.png',
    FoodVisualKey.protein: 'protein.png',
    FoodVisualKey.condiment: 'condiment.png',
    FoodVisualKey.soup: 'soup.png',
    FoodVisualKey.surimi: 'surimi.png',
    FoodVisualKey.plate: 'plate.png',
  };

  const materialIcons = <FoodVisualKey, IconData>{
    FoodVisualKey.egg: Icons.egg_alt_outlined,
    FoodVisualKey.snack: Icons.cookie_outlined,
    FoodVisualKey.drink: Icons.local_drink_outlined,
  };

  test(
    'custom assets and preserved Material Symbols cover every visual key',
    () {
      expect(FoodVisualKey.values, hasLength(14));
      expect({
        ...customAssets.keys,
        ...materialIcons.keys,
      }, containsAll(FoodVisualKey.values));
      for (final entry in customAssets.entries) {
        expect(
          FoodThumbnailAssetResolver.resolve(entry.key),
          'assets/images/food_category/${entry.value}',
        );
        expect(foodVisualKeyLabel(entry.key), entry.key.stableId.toUpperCase());
      }
      for (final entry in materialIcons.entries) {
        expect(FoodThumbnailAssetResolver.resolve(entry.key), isNull);
        expect(FoodVisualIconResolver.resolve(entry.key), entry.value);
      }
    },
  );

  test('null and unknown stable IDs resolve to the generic fallback', () {
    expect(FoodThumbnailAssetResolver.resolve(null), isNull);
    expect(FoodVisualIconResolver.resolve(null), Icons.restaurant_menu);
    expect(
      FoodVisualIconResolver.resolveStableId('unsupported'),
      Icons.restaurant_menu,
    );
  });

  testWidgets('custom assets use the shared centered contain contract', (
    tester,
  ) async {
    for (final entry in customAssets.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(child: FoodThumbnail(visualKey: entry.key, size: 52)),
          ),
        ),
      );
      final image = tester.widget<Image>(
        find.byKey(ValueKey('food-thumbnail-${entry.key.stableId}')),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/food_category/${entry.value}',
      );
      expect(
        tester
            .getSize(
              find.byKey(ValueKey('food-thumbnail-${entry.key.stableId}')),
            )
            .width,
        moreOrLessEquals(35.36),
      );
      expect(image.fit, BoxFit.contain);
      expect(image.alignment, Alignment.center);
    }
  });

  testWidgets('unaffected keys remain Material Symbols and null remains the '
      'generic fallback', (tester) async {
    for (final entry in materialIcons.entries) {
      await tester.pumpWidget(
        MaterialApp(home: FoodThumbnail(visualKey: entry.key)),
      );
      final icon = tester.widget<Icon>(
        find.byKey(ValueKey('food-thumbnail-${entry.key.stableId}')),
      );
      expect(icon.icon, entry.value);
      expect(find.byType(Image), findsNothing);
    }

    await tester.pumpWidget(
      const MaterialApp(home: FoodThumbnail(visualKey: null)),
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('food-thumbnail-fallback')))
          .icon,
      Icons.restaurant_menu,
    );
  });
}
