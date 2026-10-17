import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/widgets/food_thumbnail.dart';

void main() {
  const customAssets = <FoodVisualKey, String>{
    FoodVisualKey.meat: 'meat.png',
    FoodVisualKey.fish: 'fish.png',
    FoodVisualKey.egg: 'egg.png',
    FoodVisualKey.dairy: 'dairy.png',
    FoodVisualKey.grain: 'grain.png',
    FoodVisualKey.vegetable: 'vegetable.png',
    FoodVisualKey.fruit: 'fruit.png',
    FoodVisualKey.protein: 'protein.png',
    FoodVisualKey.condiment: 'condiment.png',
    FoodVisualKey.surimi: 'surimi.png',
    FoodVisualKey.plate: 'plate.png',
    FoodVisualKey.riceBall: 'rice_ball.jpg',
  };

  const materialIcons = <FoodVisualKey, IconData>{
    FoodVisualKey.snack: Icons.cookie_outlined,
    FoodVisualKey.drink: Icons.local_drink_outlined,
    FoodVisualKey.noodles: Symbols.ramen_dining,
    FoodVisualKey.bread: Symbols.bakery_dining,
    FoodVisualKey.soup: Symbols.skillet,
  };

  test(
    'custom assets and preserved Material Symbols cover every visual key',
    () {
      expect(FoodVisualKey.values, hasLength(17));
      expect({
        ...customAssets.keys,
        ...materialIcons.keys,
      }, containsAll(FoodVisualKey.values));
      for (final entry in customAssets.entries) {
        expect(
          FoodThumbnailAssetResolver.resolve(entry.key),
          'assets/images/food_category/${entry.value}',
        );
        expect(foodVisualKeyLabel(entry.key), switch (entry.key) {
          FoodVisualKey.grain => 'RICE',
          FoodVisualKey.riceBall => 'RICE BALL',
          _ => entry.key.stableId.toUpperCase(),
        });
      }
      for (final entry in materialIcons.entries) {
        expect(FoodThumbnailAssetResolver.resolve(entry.key), isNull);
        expect(FoodVisualIconResolver.resolve(entry.key), entry.value);
      }
    },
  );

  test(
    'thumbnail selector preserves existing order and appends new choices',
    () {
      expect(FoodVisualKey.values.map((key) => key.stableId).toList(), [
        'meat',
        'fish',
        'egg',
        'dairy',
        'grain',
        'vegetable',
        'fruit',
        'snack',
        'drink',
        'condiment',
        'protein',
        'plate',
        'soup',
        'surimi',
        'riceBall',
        'noodles',
        'bread',
      ]);
    },
  );

  test('GRAIN stable ID remains compatible while displaying RICE', () {
    expect(FoodVisualKey.fromStableId('grain'), FoodVisualKey.grain);
    expect(FoodVisualKey.grain.stableId, 'grain');
    expect(foodVisualKeyLabel(FoodVisualKey.grain), 'RICE');
    expect(
      FoodThumbnailAssetResolver.resolve(FoodVisualKey.grain),
      'assets/images/food_category/grain.png',
    );
  });

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
