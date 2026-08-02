import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/daily_log_confirmation.dart';
import 'package:or_app/core/models/meal_data.dart';
import 'package:or_app/features/daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import 'package:or_app/features/food/repository/indexed_db_food_repository.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/report_sync/services/report_sync_payload_registry.dart';
import 'package:or_app/features/report_sync/services/report_sync_payload_adapters.dart';
import 'package:or_app/features/report_sync/services/report_sync_codec.dart';
import 'package:or_app/features/training/models/custom_training_exercise.dart';
import 'package:or_app/features/training/repository/custom_training_exercise_repository.dart';

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
}

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
