import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/food_item.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/operation_date/repository/indexed_db_operation_state_repository.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/report_sync/repository/indexed_db_report_sync_repositories.dart';
import 'package:or_app/features/report_sync/services/report_sync_codec.dart';
import 'package:or_app/features/report_sync/services/report_sync_persistence_service.dart';
import 'package:or_app/features/report_sync/services/report_sync_validator.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const operationDate = '2026-08-30';

  for (final testCase in <(String, DateTime, DateTime)>[
    (
      'same-day createdAt',
      DateTime.utc(2026, 8, 30, 0, 30),
      DateTime.utc(2026, 8, 30, 0, 31),
    ),
    (
      'next-day createdAt',
      DateTime.utc(2026, 8, 31, 0, 30),
      DateTime.utc(2026, 8, 31, 0, 31),
    ),
    (
      'multi-day delayed createdAt',
      DateTime.utc(2026, 9, 5, 0, 30),
      DateTime.utc(2026, 9, 5, 0, 31),
    ),
    (
      'timezone boundary',
      DateTime.parse('2026-08-31T00:30:00+09:00'),
      DateTime.utc(2026, 8, 30, 15, 31),
    ),
  ]) {
    test(
      '${testCase.$1} maps Food history without changing operationDate',
      () async {
        final fixture = await _fixture(
          operationDate: operationDate,
          createdAt: testCase.$2,
          clock: testCase.$3,
        );

        final history = await fixture.service.importFoodMeals(
          fixture.response,
          meals: fixture.meals,
          mealCounts: const ReportSyncMealCounts(
            received: 6,
            selected: 6,
            imported: 6,
            conflict: 0,
          ),
        );

        expect(history.operationDate, operationDate);
        expect(history.importedMealCount, 6);
        expect(history.importedMealSnapshots, hasLength(6));
        expect(history.importedMealSnapshots.map((meal) => meal.mealType), [
          'Breakfast',
          'Lunch',
          'Snack',
          'Snack',
          'Dinner',
          'Snack',
        ]);
        expect(await fixture.history.list(), hasLength(1));
        expect(await fixture.database.findAll('food_records'), hasLength(6));
      },
    );
  }

  test(
    'small source clock skew is tolerated as an instant comparison',
    () async {
      final completedAt = DateTime.utc(2026, 8, 31, 0, 30);
      final fixture = await _fixture(
        operationDate: operationDate,
        createdAt: completedAt.add(const Duration(minutes: 4)),
        clock: completedAt,
        mealCount: 1,
      );

      final history = await fixture.service.importFoodMeals(
        fixture.response,
        meals: fixture.meals,
        mealCounts: const ReportSyncMealCounts(
          received: 1,
          selected: 1,
          imported: 1,
          conflict: 0,
        ),
      );

      expect(history.startedAt, completedAt);
      expect(history.completedAt, completedAt);
    },
  );

  test('clearly future createdAt remains invalid before persistence', () async {
    final fixture = await _fixture(
      operationDate: operationDate,
      createdAt: DateTime.utc(2026, 9, 6),
      clock: DateTime.utc(2026, 9, 5),
      mealCount: 1,
    );

    await expectLater(
      fixture.service.importFoodMeals(
        fixture.response,
        meals: fixture.meals,
        mealCounts: const ReportSyncMealCounts(
          received: 1,
          selected: 1,
          imported: 1,
          conflict: 0,
        ),
      ),
      throwsA(
        isA<ReportSyncImportFailure>()
            .having((error) => error.code, 'code', 'history_record_invalid')
            .having((error) => error.stage, 'stage', 'HISTORY RECORD MAPPING')
            .having(
              (error) => error.cause.toString(),
              'cause',
              contains('clock tolerance'),
            ),
      ),
    );
    expect(await fixture.history.list(), isEmpty);
    expect(await fixture.database.findAll('food_records'), isEmpty);
  });
}

Future<
  ({
    FakeIndexedDbDatabase database,
    IndexedDbReportSyncHistoryRepository history,
    ReportSyncPersistenceService service,
    ReportSyncEnvelope response,
    List<MealData> meals,
  })
>
_fixture({
  required String operationDate,
  required DateTime createdAt,
  required DateTime clock,
  int mealCount = 6,
}) async {
  final database = FakeIndexedDbDatabase();
  final history = IndexedDbReportSyncHistoryRepository(database);
  final operationState = IndexedDbOperationStateRepository(database);
  await operationState.createInitial(OperationLocalDate.parse(operationDate));
  final service = ReportSyncPersistenceService(
    database: database,
    historyRepository: history,
    validator: ReportSyncValidator(
      historyRepository: history,
      operationStateRepository: operationState,
    ),
    clock: () => clock,
  );
  final mealTypes = ['Breakfast', 'Lunch', 'Snack', 'Snack', 'Dinner', 'Snack'];
  final meals = [
    for (var index = 0; index < mealCount; index++)
      MealData(
        date: operationDate,
        mealType: mealTypes[index % mealTypes.length],
        items: [
          FoodItem(
            name: 'Item $index',
            calories: 100 + index,
            protein: 10,
            fat: 5,
            carbohydrate: 12,
          ),
        ],
        memo: '',
        id: 'FL-$operationDate-${(index + 1).toString().padLeft(3, '0')}',
      ),
  ];
  final response = const ReportSyncCodec().create(
    direction: ReportSyncDirection.response,
    exchangeType: ReportSyncExchangeType.food,
    exchangeId: 'temporal-${createdAt.toUtc().microsecondsSinceEpoch}',
    operationDate: operationDate,
    createdAt: createdAt,
    schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
    payload: {
      'operationDate': operationDate,
      'meals': [
        for (var index = 0; index < mealCount; index++)
          {
            'sourceMealId': 'source-$index',
            'mealType': mealTypes[index % mealTypes.length],
            'items': [
              {
                'name': 'Item $index',
                'calories': 100 + index,
                'protein': 10,
                'fat': 5,
                'carbohydrate': 12,
                'quantity': 1,
                'amount': null,
                'baseAmount': null,
                'baseUnit': null,
                'amountMode': null,
              },
            ],
            'memo': '',
            'waterMl': null,
          },
      ],
    },
  );
  return (
    database: database,
    history: history,
    service: service,
    response: response,
    meals: meals,
  );
}
