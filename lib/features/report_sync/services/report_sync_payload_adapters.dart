import '../../../core/models/food_item.dart';
import '../../../core/models/meal_data.dart';
import '../../../data/indexed_db/indexed_db_database_contract.dart';
import '../../../data/indexed_db/indexed_db_store_names.dart';
import '../../daily_log_confirmation/repository/daily_log_confirmation_repository.dart';
import '../../food/repository/food_repository.dart';
import '../../food/models/persisted_food_record.dart';
import '../../training/repository/custom_training_exercise_repository.dart';
import '../../training/sync/training_sync_schema.dart';
import '../models/report_sync_envelope.dart';
import 'report_sync_canonical_service.dart';
import 'report_sync_payload_registry.dart';

class TrainingReportSyncPayloadAdapter {
  final CustomTrainingExerciseRepository customExercises;
  const TrainingReportSyncPayloadAdapter(this.customExercises);

  Future<TrainingSyncPayload> decodeResponse(
    ReportSyncEnvelope response,
  ) async {
    if (response.exchangeType != ReportSyncExchangeType.training ||
        response.direction != ReportSyncDirection.response) {
      throw const FormatException('Training response required.');
    }
    const TrainingReportSyncPayloadSchema().validateResponse(response.payload);
    return TrainingSyncSchema.decode(
      payload: Map<String, Object?>.from(response.payload['session'] as Map),
      operationDate: response.operationDate,
      idempotencyKey: response.payload['idempotencyKey'] as String,
      customExercises: customExercises,
    );
  }
}

class FoodReportSyncPayloadMapper {
  const FoodReportSyncPayloadMapper();

  Map<String, Object?> buildRequest({
    required String operationDate,
    required List<MealData> meals,
    required String requestPurpose,
    Map<String, Object?> dailySummary = const {},
    List<Object?> knownFoodReferences = const [],
    Map<String, Object?> instructionContext = const {},
  }) => {
    'operationDate': operationDate,
    'requestPurpose': requestPurpose,
    'meals': meals.map(_mealToJson).toList(),
    'dailySummary': dailySummary,
    'knownFoodReferences': knownFoodReferences,
    'instructionContext': instructionContext,
  };

  static Map<String, Object?> _mealToJson(MealData meal) => {
    'mealId': meal.id,
    'mealType': meal.mealType,
    'items': meal.items
        .map(
          (item) => <String, Object?>{
            'name': item.name,
            'calories': item.calories,
            'protein': item.protein,
            'fat': item.fat,
            'carbohydrate': item.carbohydrate,
            'quantity': item.quantity,
            'amount': item.amount,
            'baseAmount': item.baseAmount,
            'baseUnit': item.baseUnit?.label,
            'amountMode': item.amountMode?.serializedValue,
          },
        )
        .toList(),
    'memo': meal.memo,
    'waterMl': meal.waterMl,
  };

  List<MealData> decodeResponse(ReportSyncEnvelope response) {
    if (response.exchangeType != ReportSyncExchangeType.food ||
        response.direction != ReportSyncDirection.response) {
      throw const FormatException('Food response required.');
    }
    const FoodReportSyncPayloadSchema().validateResponse(response.payload);
    return [
      for (final raw in response.payload['meals'] as List)
        _mealFromJson(
          response.operationDate,
          Map<String, Object?>.from(raw as Map),
        ),
    ];
  }

  static MealData _mealFromJson(String date, Map<String, Object?> json) =>
      MealData(
        date: date,
        mealType: json['mealType'] as String,
        items: [
          for (final raw in json['items'] as List)
            _itemFromJson(Map<String, Object?>.from(raw as Map)),
        ],
        memo: json['memo'] as String? ?? '',
        id: json['mealId'] as String,
        waterMl: (json['waterMl'] as num?)?.toDouble(),
      );

  static FoodItem _itemFromJson(Map<String, Object?> json) => FoodItem(
    name: json['name'] as String,
    calories: json['calories'] as num,
    protein: (json['protein'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
    carbohydrate: (json['carbohydrate'] as num).toDouble(),
    quantity: json['quantity'] as int,
    amount: (json['amount'] as num?)?.toDouble(),
    baseAmount: (json['baseAmount'] as num?)?.toDouble(),
    baseUnit: json['baseUnit'] == null
        ? null
        : FoodBaseUnit.parse(json['baseUnit'] as String),
    amountMode: json['amountMode'] == null
        ? null
        : FoodAmountMode.parse(json['amountMode'] as String),
  );
}

enum FoodReportSyncApplyStatus { created, noChange, conflict, finalizedBlocked }

class FoodReportSyncApplyResult {
  final FoodReportSyncApplyStatus status;
  final int readBackVerifiedCount;
  const FoodReportSyncApplyResult(this.status, this.readBackVerifiedCount);
}

class FoodReportSyncApplyAdapter {
  final FoodRepository repository;
  final DailyLogConfirmationStore confirmations;
  final FoodReportSyncPayloadMapper mapper;
  final IndexedDbDatabase? database;
  final DateTime Function() clock;
  const FoodReportSyncApplyAdapter({
    required this.repository,
    required this.confirmations,
    this.mapper = const FoodReportSyncPayloadMapper(),
    this.database,
    this.clock = DateTime.now,
  });

  Future<FoodReportSyncApplyResult> apply(ReportSyncEnvelope response) async {
    if (await confirmations.isConfirmed(response.operationDate)) {
      return const FoodReportSyncApplyResult(
        FoodReportSyncApplyStatus.finalizedBlocked,
        0,
      );
    }
    final meals = mapper.decodeResponse(response);
    final targetDatabase = database;
    if (targetDatabase != null) {
      return _applyAtomic(targetDatabase, meals);
    }
    var noChange = 0;
    for (final meal in meals) {
      final existing = await repository.findById(meal.id);
      if (existing == null) continue;
      if (_equal(existing, meal)) {
        noChange++;
        continue;
      }
      return const FoodReportSyncApplyResult(
        FoodReportSyncApplyStatus.conflict,
        0,
      );
    }
    var verified = 0;
    for (final meal in meals) {
      if (await repository.findById(meal.id) == null) {
        await repository.save(meal);
      }
      final stored = await repository.findById(meal.id);
      if (stored == null || !_equal(stored, meal)) {
        throw StateError('Food REPORT SYNC read-back verification failed.');
      }
      verified++;
    }
    return FoodReportSyncApplyResult(
      noChange == meals.length
          ? FoodReportSyncApplyStatus.noChange
          : FoodReportSyncApplyStatus.created,
      verified,
    );
  }

  Future<FoodReportSyncApplyResult> _applyAtomic(
    IndexedDbDatabase database,
    List<MealData> meals,
  ) => database.runTransaction(
    storeNames: const [IndexedDbStoreNames.foodRecords],
    mode: IndexedDbTransactionMode.readWrite,
    action: (transaction) async {
      final existingByMealId = <String, Map<String, Object?>?>{};
      var noChange = 0;
      for (final meal in meals) {
        final id = PersistedFoodRecord.envelopeId(meal.id);
        final existing = await transaction.findById(
          IndexedDbStoreNames.foodRecords,
          id,
        );
        existingByMealId[meal.id] = existing;
        if (existing == null) continue;
        final persisted = PersistedFoodRecord.fromRecord(existing);
        if (!_equal(persisted.data, meal)) {
          return const FoodReportSyncApplyResult(
            FoodReportSyncApplyStatus.conflict,
            0,
          );
        }
        noChange++;
      }
      final now = clock().toUtc();
      for (final meal in meals) {
        if (existingByMealId[meal.id] != null) continue;
        await transaction.put(
          IndexedDbStoreNames.foodRecords,
          PersistedFoodRecord(
            id: PersistedFoodRecord.envelopeId(meal.id),
            localDate: PersistedFoodRecord.localDateFromMealDate(meal.date),
            createdAt: now,
            updatedAt: now,
            data: meal,
          ).toRecord(),
        );
      }
      var verified = 0;
      for (final meal in meals) {
        final readBack = await transaction.findById(
          IndexedDbStoreNames.foodRecords,
          PersistedFoodRecord.envelopeId(meal.id),
        );
        if (readBack == null ||
            !_equal(PersistedFoodRecord.fromRecord(readBack).data, meal)) {
          throw StateError('Food REPORT SYNC read-back verification failed.');
        }
        verified++;
      }
      return FoodReportSyncApplyResult(
        noChange == meals.length
            ? FoodReportSyncApplyStatus.noChange
            : FoodReportSyncApplyStatus.created,
        verified,
      );
    },
  );

  static bool _equal(MealData first, MealData second) =>
      ReportSyncCanonicalService.encode(first.toJson()) ==
      ReportSyncCanonicalService.encode(second.toJson());
}
