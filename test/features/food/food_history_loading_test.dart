import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/food/food_history_page.dart';
import 'package:or_app/features/food/models/persisted_food_record.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  late FakeIndexedDbDatabase database;
  late AppInitializationController controller;

  setUp(() {
    database = FakeIndexedDbDatabase();
    controller = AppInitializationController()..markReady();
    AppRepositoryRegistry.beginStartup(controller: controller);
    AppRepositoryRegistry.install(AppRepositoryContainer.indexedDb(database));
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
