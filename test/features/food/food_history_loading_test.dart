import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/food_history_page.dart';
import 'package:or_app/features/food/models/daily_meal_v2_models.dart';
import 'package:or_app/features/food/models/food_catalog_models.dart';
import 'package:or_app/features/food/models/food_provenance_models.dart';
import 'package:or_app/features/food/models/food_quantity_models.dart';
import 'package:or_app/features/food/models/nutrition_models.dart';
import 'package:or_app/features/food/models/persisted_daily_meal_v2_record.dart';
import 'package:or_app/features/food/models/persisted_food_record.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';
import '../operation_date/operation_date_test_fixture.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
    seedOperationState(database, '2026-07-26');
  });

  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('immutable empty result stops loading and shows empty state', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No meal records.'), findsOneWidget);
  });

  testWidgets('immutable one-record result stops loading', (tester) async {
    _seed(database, _meal(id: 'meal-1', date: '2026-07-25'));

    await _pumpPage(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Breakfast'), findsOneWidget);
  });

  testWidgets('multiple records are displayed in descending date order', (
    tester,
  ) async {
    _seed(database, _meal(id: 'older', date: '2026-07-24'));
    _seed(database, _meal(id: 'newer', date: '2026-07-26'));

    await _pumpPage(tester);

    final newerTop = tester.getTopLeft(find.text('2026-07-26').first).dy;
    final olderTop = tester.getTopLeft(find.text('2026-07-24').first).dy;
    expect(newerTop, lessThan(olderTop));
  });

  testWidgets('Quick Water and normal meal both render', (tester) async {
    _seed(database, _meal(id: 'water', date: '2026-07-26', waterMl: 500));
    _seed(database, _meal(id: 'meal', date: '2026-07-26'));

    await _pumpPage(tester);

    expect(find.text('Water'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
  });

  testWidgets('measured food shows amount and calculated nutrition', (
    tester,
  ) async {
    _seed(
      database,
      MealData(
        id: 'measured',
        date: '2026-07-26',
        mealType: 'Lunch',
        items: const [
          FoodItem(
            name: 'Chicken',
            calories: 165,
            protein: 31,
            fat: 3.6,
            carbohydrate: 0,
            amount: 250,
            baseAmount: 100,
            baseUnit: FoodBaseUnit.g,
          ),
        ],
        memo: '',
      ),
    );

    await _pumpPage(tester);

    expect(find.text('Chicken  250g'), findsOneWidget);
    expect(find.textContaining('413 kcal'), findsOneWidget);
    expect(find.textContaining('P 77.5'), findsOneWidget);
  });

  testWidgets('v2 history resolves thumbnail only through Food Master ID', (
    tester,
  ) async {
    final entry = _catalog(FoodVisualKey.meat);
    database.seed(
      IndexedDbStoreNames.foodCatalogRecords,
      entry.foodId,
      entry.toJson(),
    );
    _seedV2(database, foodReferenceId: entry.foodId, name: 'Linked Food');

    await _pumpPage(tester);

    expect(find.text('Linked Food'), findsOneWidget);
    expect(find.byKey(const ValueKey('food-thumbnail-meat')), findsOneWidget);
    expect(find.text('ADD TO FOOD DATABASE'), findsNothing);
  });

  testWidgets('legacy and unlinked v2 history use generic fallback', (
    tester,
  ) async {
    _seed(database, _meal(id: 'legacy', date: '2026-07-25'));
    _seedV2(database, foodReferenceId: null, name: 'Unlinked Food');

    await _pumpPage(tester);

    expect(find.text('Unlinked Food'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('food-thumbnail-fallback')),
      findsNWidgets(2),
    );
    expect(find.text('ADD TO FOOD DATABASE'), findsNWidgets(2));
  });

  testWidgets('v2 delete removes only the selected Formal meal', (
    tester,
  ) async {
    _seedV2(database, foodReferenceId: null, name: 'Delete Target');
    _seedV2(
      database,
      mealId: '66666666-6666-4666-8666-666666666666',
      foodReferenceId: null,
      name: 'Keep Target',
    );
    await _pumpPage(tester);

    await tester.tap(
      find.byKey(
        const ValueKey('delete-v2-meal-44444444-4444-4444-8444-444444444444'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Target'), findsNothing);
    expect(find.text('Keep Target'), findsOneWidget);
    expect(
      await AppRepositoryRegistry.container.dailyMealsV2.readById(
        '44444444-4444-4444-8444-444444444444',
      ),
      isNull,
    );
  });

  testWidgets('v2 delete failure keeps record visible', (tester) async {
    _seedV2(database, foodReferenceId: null, name: 'Retry Target');
    await _pumpPage(tester);
    database.failNextTransactionWith = StateError('delete failed');

    await tester.tap(
      find.byKey(
        const ValueKey('delete-v2-meal-44444444-4444-4444-8444-444444444444'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.text('Retry Target'), findsOneWidget);
    expect(find.text('MEAL DELETE FAILED'), findsOneWidget);
    expect(
      await AppRepositoryRegistry.container.dailyMealsV2.readById(
        '44444444-4444-4444-8444-444444444444',
      ),
      isNotNull,
    );
  });

  testWidgets('v2 delete respects the finalized operation-date lock', (
    tester,
  ) async {
    _seedV2(database, foodReferenceId: null, name: 'Locked Target');
    final state = database.rawRecord('operation_state', 'current')!;
    database.seed('operation_state', 'current', {
      ...state,
      'phase': 'finalizing',
      'activeAttempt': {
        'idempotencyKey': 'delete-lock-test',
        'targetLocalDate': '2026-07-26',
        'startedAt': '2026-07-26T12:00:00.000Z',
        'confirmationId': null,
        'confirmationDigest': null,
        'backupPackageDigest': null,
        'backupGeneratedAt': null,
        'failureCode': null,
      },
    });
    await _pumpPage(tester);

    await tester.tap(
      find.byKey(
        const ValueKey('delete-v2-meal-44444444-4444-4444-8444-444444444444'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();

    expect(find.text('Locked Target'), findsOneWidget);
    expect(find.textContaining('この日のログは確定済みです'), findsOneWidget);
    expect(
      await AppRepositoryRegistry.container.dailyMealsV2.readById(
        '44444444-4444-4444-8444-444444444444',
      ),
      isNotNull,
    );
  });

  testWidgets('archived Food Master linkage exposes add action', (
    tester,
  ) async {
    final entry = FoodCatalogEntry.fromJson({
      ..._catalog(FoodVisualKey.meat).toJson(),
      'isArchived': true,
    });
    database.seed(
      IndexedDbStoreNames.foodCatalogRecords,
      entry.foodId,
      entry.toJson(),
    );
    _seedV2(database, foodReferenceId: entry.foodId, name: 'Archived Link');

    await _pumpPage(tester);

    expect(find.text('ADD TO FOOD DATABASE'), findsOneWidget);
  });

  testWidgets('same Food name without stable linkage remains unregistered', (
    tester,
  ) async {
    final entry = _catalog(FoodVisualKey.meat);
    database.seed(
      IndexedDbStoreNames.foodCatalogRecords,
      entry.foodId,
      entry.toJson(),
    );
    _seedV2(database, foodReferenceId: null, name: entry.name);

    await _pumpPage(tester);

    expect(find.text('ADD TO FOOD DATABASE'), findsOneWidget);
  });

  testWidgets('repository error replaces spinner with error and Retry', (
    tester,
  ) async {
    database.seed(IndexedDbStoreNames.foodRecords, 'food:bad', {
      'id': 'food:bad',
      'recordVersion': 999,
    });

    await _pumpPage(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Unable to load food records.'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('No meal records.'), findsNothing);
  });

  testWidgets('Retry uses the same loader and can recover', (tester) async {
    database.seed(IndexedDbStoreNames.foodRecords, 'food:bad', {
      'id': 'food:bad',
      'recordVersion': 999,
    });
    await _pumpPage(tester);
    await database.deleteById(IndexedDbStoreNames.foodRecords, 'food:bad');
    _seed(database, _meal(id: 'recovered', date: '2026-07-26'));

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to load food records.'), findsNothing);
    expect(find.text('Breakfast'), findsOneWidget);
  });

  testWidgets('disposing before read completion does not call setState', (
    tester,
  ) async {
    final delayedDatabase = _DelayedFoodDatabase();
    AppRepositoryRegistry.install(
      AppRepositoryContainer.indexedDb(delayedDatabase),
    );
    await tester.pumpWidget(const MaterialApp(home: FoodHistoryPage()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    delayedDatabase.complete(const []);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: FoodHistoryPage()));
  await tester.pumpAndSettle();
}

MealData _meal({required String id, required String date, double? waterMl}) {
  return MealData(
    id: id,
    date: date,
    mealType: waterMl == null ? 'Breakfast' : 'Water',
    items: waterMl == null
        ? const [
            FoodItem(
              name: 'Rice',
              calories: 200,
              protein: 4,
              fat: 1,
              carbohydrate: 45,
            ),
          ]
        : const [],
    memo: '',
    waterMl: waterMl,
  );
}

void _seed(FakeIndexedDbDatabase database, MealData meal) {
  final timestamp = DateTime.utc(2026, 7, 26);
  final record = PersistedFoodRecord(
    id: PersistedFoodRecord.envelopeId(meal.id),
    localDate: PersistedFoodRecord.localDateFromMealDate(meal.date),
    createdAt: timestamp,
    updatedAt: timestamp,
    data: meal,
  ).toRecord();
  database.seed(
    IndexedDbStoreNames.foodRecords,
    record['id']! as String,
    record,
  );
}

void _seedV2(
  FakeIndexedDbDatabase database, {
  String mealId = '44444444-4444-4444-8444-444444444444',
  required String? foodReferenceId,
  required String name,
}) {
  final timestamp = DateTime.utc(2026, 7, 26);
  final meal = DailyMealV2(
    mealId: mealId,
    localDate: '2026-07-26',
    mealType: DailyMealTypeV2.lunch,
    items: [
      DailyMealItemSnapshot(
        mealItemId: '55555555-5555-4555-8555-555555555555',
        foodReferenceId: foodReferenceId,
        nameSnapshot: name,
        quantity: FoodQuantityDefinition(
          value: 1,
          unit: FoodQuantityUnit.serving,
        ),
        nutritionPerBase: NutritionSnapshot(calories: 200),
        nutritionConsumed: NutritionSnapshot(calories: 200),
        provenanceSnapshot: FoodDataProvenance(
          sourceType: FoodProvenanceSourceType.userInput,
          capturedAt: timestamp,
        ),
        nutritionStatusSnapshot: NutritionStatus.declared,
        sortOrder: 0,
      ),
    ],
    createdAt: timestamp,
    updatedAt: timestamp,
  );
  final record = PersistedDailyMealV2Record.fromMeal(meal).toRecord();
  database.seed(
    IndexedDbStoreNames.foodRecords,
    record['id']! as String,
    record,
  );
}

FoodCatalogEntry _catalog(FoodVisualKey visualKey) {
  final timestamp = DateTime.utc(2026, 7, 26);
  return FoodCatalogEntry(
    foodId: '11111111-1111-4111-8111-111111111111',
    name: 'Linked Food',
    category: FoodCatalogCategory.ingredient,
    visualKey: visualKey,
    baseQuantity: FoodQuantityDefinition(
      value: 100,
      unit: FoodQuantityUnit.gram,
    ),
    nutrition: NutritionSnapshot(calories: 200),
    nutritionStatus: NutritionStatus.declared,
    provenance: FoodDataProvenance(
      sourceType: FoodProvenanceSourceType.userInput,
      capturedAt: timestamp,
    ),
    isArchived: false,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _DelayedFoodDatabase extends FakeIndexedDbDatabase {
  final _completer = Completer<List<Map<String, Object?>>>();

  @override
  Future<List<Map<String, Object?>>> findAll(String storeName) {
    if (storeName == IndexedDbStoreNames.foodRecords) {
      return _completer.future;
    }
    return super.findAll(storeName);
  }

  void complete(List<Map<String, Object?>> records) {
    _completer.complete(records);
  }
}
