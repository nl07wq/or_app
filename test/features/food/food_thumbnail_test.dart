import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/widgets/food_thumbnail.dart';

void main() {
  test('all visual keys resolve to their dedicated PNG asset', () {
    expect(FoodVisualKey.values, hasLength(11));
    for (final key in FoodVisualKey.values) {
      expect(
        FoodVisualAssetResolver.path(key),
        'assets/images/food_category/${key.stableId}.png',
      );
      expect(foodVisualKeyLabel(key), key.stableId.toUpperCase());
    }
  });

  testWidgets('all supplied assets load from the Flutter bundle', (
    tester,
  ) async {
    for (final key in FoodVisualKey.values) {
      final bytes = await rootBundle.load(FoodVisualAssetResolver.path(key));
      expect(bytes.lengthInBytes, greaterThan(0), reason: key.stableId);
    }
  });

  testWidgets('null and unresolved assets use the generic food fallback', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _MissingAssetBundle(),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const FoodThumbnail(visualKey: FoodVisualKey.meat),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('food-thumbnail-fallback')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _MissingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(StateError('Missing test asset: $key'));
}
