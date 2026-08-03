import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_repository.dart';
import 'package:or_app/features/food/repository/food_meal_id_generator.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/services/report_sync_payload_registry.dart';
import 'package:or_app/features/report_sync/services/report_sync_payload_adapters.dart';
import 'package:or_app/features/report_sync/services/report_sync_codec.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/repository/custom_training_exercise_repository.dart';
import 'package:or_app/features/training/repository/training_record_id_generator.dart';
import 'package:or_app/features/training/services/exercise_name_localization.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  final registry = ReportSyncPayloadRegistry.standard();

  test('registers strict schemas for all four exchange types', () {
    for (final type in ReportSyncExchangeType.values) {
      expect(registry.forType(type).exchangeType, type);
      expect(registry.forType(type).minimalResponseExample, isNotEmpty);
    }
  });

  test('Food payload preserves null separately from numeric zero', () {
    final schema = registry.forType(ReportSyncExchangeType.food);
    schema.validateResponse({
      'requestId': 'request-food',
      'requestDigest':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'operationDate': '2026-08-02',
      'meals': [
        {
          'mealId': 'meal-1',
          'mealType': 'Breakfast',
          'items': [
            {
              'name': 'Food',
              'calories': 0,
              'protein': 0,
              'fat': 0,
              'carbohydrate': 0,
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
    });
  });

  test('Morning Brief rejects unknown status and fields', () {
    final schema = registry.forType(ReportSyncExchangeType.morningBrief);
    final value = Map<String, Object?>.from(schema.minimalResponseExample);
    final content = Map<String, Object?>.from(value['content'] as Map);
    value['content'] = {...content, 'operationStatus': 'standby'};
    expect(
      () => schema.validateResponse(value),
      throwsA(isA<ReportSyncException>()),
    );
    value['content'] = {...content, 'extra': true};
    expect(
      () => schema.validateResponse(value),
      throwsA(isA<ReportSyncException>()),
    );
  });

  test('formal payload fixtures match all four schemas', () {
    for (final entry in <ReportSyncExchangeType, String>{
      ReportSyncExchangeType.training: 'training',
      ReportSyncExchangeType.food: 'food',
      ReportSyncExchangeType.morningBrief: 'morning_brief',
      ReportSyncExchangeType.dailyDebrief: 'daily_debrief',
    }.entries) {
      final schema = registry.forType(entry.key);
      schema.validateRequest(_fixture('${entry.value}_request.json'));
      schema.validateResponse(_fixture('${entry.value}_response.json'));
    }
  });

  test(
    'formal Training response bridges to Training Sync Schema 1.0',
    () async {
      final payload = _fixture('training_response.json');
      final response = const ReportSyncCodec().create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.training,
        exchangeId: 'exchange-training-1',
        operationDate: payload['operationDate'] as String,
        createdAt: DateTime.utc(2026, 8, 2),
        payload: payload,
      );
      final decoded = await TrainingReportSyncPayloadAdapter(
        _EmptyCustomExercises(),
      ).decodeResponse(response);
      expect(decoded.recordId, 'training-report-1');
    },
  );

  test(
    'Food apply is idempotent, detects conflict, and blocks finalized dates',
    () async {
      final payload = _fixture('food_response.json');
      final response = const ReportSyncCodec().create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.food,
        exchangeId: 'exchange-food-1',
        operationDate: payload['operationDate'] as String,
        createdAt: DateTime.utc(2026, 8, 2),
        payload: payload,
      );
      final database = FakeIndexedDbDatabase();
      final foods = IndexedDbFoodRepository(
        database,
        now: () => DateTime.utc(2026, 8, 2),
      );
      final confirmations = _ConfirmationStore();
      final adapter = FoodReportSyncApplyAdapter(
        repository: foods,
        confirmations: confirmations,
        database: database,
        clock: () => DateTime.utc(2026, 8, 2),
      );
      expect(
        (await adapter.apply(response)).status,
        FoodReportSyncApplyStatus.created,
      );
      expect(
        (await adapter.apply(response)).status,
        FoodReportSyncApplyStatus.noChange,
      );
      await foods.update(
        MealData.fromJson({
          ...(await foods.findById('meal-report-1'))!.toJson(),
          'memo': 'changed',
        }),
      );
      expect(
        (await adapter.apply(response)).status,
        FoodReportSyncApplyStatus.conflict,
      );
      confirmations.confirmed = true;
      expect(
        (await adapter.apply(response)).status,
        FoodReportSyncApplyStatus.finalizedBlocked,
      );
    },
  );

  test('Food response requires non-empty meals with unique meal IDs', () {
    const schema = FoodReportSyncPayloadSchema();
    expect(
      () => schema.validateResponse(const {
        'operationDate': '2026-08-02',
        'meals': <Object?>[],
      }),
      throwsA(isA<ReportSyncException>()),
    );
    const meal = {
      'mealId': 'duplicate',
      'mealType': 'Water',
      'items': <Object?>[],
      'memo': null,
      'waterMl': 250,
    };
    expect(
      () => schema.validateResponse(const {
        'operationDate': '2026-08-02',
        'meals': [meal, meal],
      }),
      throwsA(isA<ReportSyncException>()),
    );
  });

  test(
    'Training Schema 2 maps external identity to formal domain identity',
    () async {
      final response = const ReportSyncCodec().create(
        direction: ReportSyncDirection.response,
        exchangeType: ReportSyncExchangeType.training,
        exchangeId: 'training-schema-2',
        operationDate: '2026-08-01',
        createdAt: DateTime.utc(2026, 8, 2),
        schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
        payload: _trainingV2Payload(),
      );
      final raw = const ReportSyncCodec().encode(response);
      final strict = const ReportSyncCodec().decode(raw);
      final mapped = await TrainingReportSyncPayloadAdapter(
        _EmptyCustomExercises(),
        idGenerator: TrainingRecordIdGenerator(nextInt: (_) => 0),
      ).decodeResponse(strict);

      expect(strict.hasValidPackageDigest, isTrue);
      expect(mapped.recordId, matches(RegExp(r'^training:[0-9a-f-]{36}$')));
      expect(mapped.recordId, isNot('TR-2026-08-01'));
      expect(mapped.exerciseIds.single, exerciseIdentityKey('Bench Press'));
      expect(mapped.session.exercises.single.equipment?.catalogId, isNull);
      expect(mapped.session.exercises.single.equipment?.name, 'Power Rack');
      expect(
        mapped.session.exercises.single.nextTarget?.targetWeightKg,
        isNull,
      );
      expect(mapped.session.exercises.single.nextTarget?.targetReps, isEmpty);
      expect(mapped.session.exercises.single.nextTarget?.notes, 'フォームを維持する');
    },
  );

  test('Schema 2 detailed validation exposes a safe JSON path', () {
    final payload = _trainingV2Payload();
    final session = Map<String, Object?>.from(payload['session'] as Map);
    final exercises = List<Object?>.from(session['exercises'] as List);
    exercises[0] = {
      ...Map<String, Object?>.from(exercises[0] as Map),
      'nextTarget': 10,
    };
    session['exercises'] = exercises;
    payload['session'] = session;
    final response = const ReportSyncCodec().create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.training,
      exchangeId: 'invalid-training-schema-2',
      operationDate: '2026-08-01',
      createdAt: DateTime.utc(2026, 8, 2),
      schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
      payload: payload,
    );

    expect(
      () => const ReportSyncCodec().decode(
        const ReportSyncCodec().encode(response),
      ),
      throwsA(
        isA<ReportSyncException>()
            .having(
              (error) => error.validationError?.jsonPath,
              'jsonPath',
              r'$.payload.session.exercises[0].nextTarget',
            )
            .having(
              (error) => error.validationError?.expected,
              'expected',
              'String or null',
            ),
      ),
    );
  });

  test('Food Schema 2 separates source, preview, conflict, and storage IDs', () {
    var byte = 0;
    final mapper = FoodReportSyncPayloadMapper(
      idGenerator: FoodMealIdGenerator(nextInt: (_) => byte++ & 0xff),
    );
    final response = const ReportSyncCodec().create(
      direction: ReportSyncDirection.response,
      exchangeType: ReportSyncExchangeType.food,
      exchangeId: 'food-schema-2',
      operationDate: '2026-08-01',
      createdAt: DateTime.utc(2026, 8, 2),
      schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
      payload: {
        'operationDate': '2026-08-01',
        'meals': [
          _foodV2Meal('source-breakfast', 'Breakfast', 'Oats'),
          _foodV2Meal(null, 'Lunch', 'Rice'),
        ],
      },
    );
    final decoded = mapper.decodeResponseMeals(response);

    expect(decoded.map((meal) => meal.previewId), [
      'food-preview-0',
      'food-preview-1',
    ]);
    expect(decoded.first.sourceMealId, 'source-breakfast');
    expect(decoded.last.sourceMealId, isNull);
    expect(decoded.map((meal) => meal.meal.id).toSet(), hasLength(2));
    expect(
      decoded.every(
        (meal) => RegExp(
          r'^food:[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(meal.meal.id),
      ),
      isTrue,
    );
    final sameContentDifferentId = MealData.fromJson({
      ...decoded.first.meal.toJson(),
      'id': 'food:ffffffff-ffff-4fff-8fff-ffffffffffff',
    });
    expect(
      FoodReportSyncPayloadMapper.conflictDigest(decoded.first.meal),
      FoodReportSyncPayloadMapper.conflictDigest(sameContentDifferentId),
    );
  });
}

Map<String, Object?> _trainingV2Payload() => {
  'operationDate': '2026-08-01',
  'sourceRecordId': 'TR-2026-08-01',
  'session': {
    'session': {
      'localDate': '2026-08-01',
      'name': 'Session',
      'grade': 'a',
      'memo': null,
      'dynamicStretchCompleted': false,
      'cooldownStretchCompleted': false,
      'overallEvaluation': null,
    },
    'exercises': [
      {
        'exerciseName': 'Bench Press',
        'equipment': {'id': null, 'name': 'Power Rack'},
        'sets': [
          {
            'type': 'main',
            'weightKg': 60,
            'reps': 5,
            'rpe': null,
            'restAfterSeconds': 90,
          },
        ],
        'evaluation': null,
        'nextTarget': 'フォームを維持する',
      },
    ],
    'cardio': <Object?>[],
  },
};

Map<String, Object?> _foodV2Meal(
  String? sourceMealId,
  String mealType,
  String name,
) => {
  'sourceMealId': sourceMealId,
  'mealType': mealType,
  'items': [
    {
      'name': name,
      'calories': 100,
      'protein': 4,
      'fat': 2,
      'carbohydrate': 18,
      'quantity': 1,
      'amount': null,
      'baseAmount': null,
      'baseUnit': null,
      'amountMode': null,
    },
  ],
  'memo': null,
  'waterMl': null,
};

Map<String, Object?> _fixture(String name) => Map<String, Object?>.from(
  jsonDecode(File('test/fixtures/report_sync/$name').readAsStringSync()) as Map,
);

class _EmptyCustomExercises implements CustomTrainingExerciseRepository {
  @override
  Future<void> clear() async {}
  @override
  Future<CustomTrainingExercise> create(String name) =>
      throw UnimplementedError();
  @override
  Future<void> deleteById(String id) async {}
  @override
  Future<List<CustomTrainingExercise>> findAll() async => const [];
  @override
  Future<CustomTrainingExercise?> findById(String id) async => null;
  @override
  Future<CustomTrainingExercise> updateById(String id, String name) =>
      throw UnimplementedError();
}

class _ConfirmationStore implements DailyLogConfirmationStore {
  bool confirmed = false;
  @override
  Future<bool> isConfirmed(String localDate) async => confirmed;
  @override
  Future<void> clear() async {}
  @override
  Future<void> deleteByLocalDate(String localDate) async {}
  @override
  Future<List<DailyLogConfirmation>> findAll() async => const [];
  @override
  Future<DailyLogConfirmation?> findByLocalDate(String localDate) async => null;
  @override
  Future<DailyLogConfirmation?> findLatest() async => null;
  @override
  Future<void> save(DailyLogConfirmation confirmation) async {}
}
