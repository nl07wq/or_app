import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/food/services/food_history_catalog_registration_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persists independent legacy and V2 record-item catalog links',
    () async {
      final legacy = FoodHistoryCatalogRegistrationStore.legacyItemKey(
        'meal-1',
        0,
      );
      final v2 = FoodHistoryCatalogRegistrationStore.v2ItemKey(
        'meal-1',
        'item-1',
      );

      await FoodHistoryCatalogRegistrationStore.link(
        recordItemKey: legacy,
        catalogId: 'catalog-a',
      );
      await FoodHistoryCatalogRegistrationStore.link(
        recordItemKey: v2,
        catalogId: 'catalog-b',
      );

      expect(await FoodHistoryCatalogRegistrationStore.readAll(), {
        legacy: 'catalog-a',
        v2: 'catalog-b',
      });
    },
  );

  test('does not use food names as registration identity', () {
    expect(
      FoodHistoryCatalogRegistrationStore.legacyItemKey('meal-a', 0),
      isNot(FoodHistoryCatalogRegistrationStore.legacyItemKey('meal-b', 0)),
    );
  });
}
