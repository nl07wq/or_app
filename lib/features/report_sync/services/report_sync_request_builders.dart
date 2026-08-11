import '../../morning/models/morning_fact.dart';
import 'report_sync_payload_registry.dart';

class TrainingRequestPayloadBuilder {
  const TrainingRequestPayloadBuilder();

  Map<String, Object?> build({
    required String operationDate,
    required String requestPurpose,
    required Map<String, Object?>? currentSession,
    Object? recentTrainingSummary,
    List<Object?> registeredExercises = const [],
    List<Object?> registeredEquipment = const [],
    num? sameDateStatusWeight,
    Map<String, Object?> instructionContext = const {},
  }) {
    final payload = <String, Object?>{
      'operationDate': operationDate,
      'requestPurpose': requestPurpose,
      'currentSession': currentSession,
      'recentTrainingSummary': recentTrainingSummary,
      'registeredExercises': registeredExercises,
      'registeredEquipment': registeredEquipment,
      'statusWeight': sameDateStatusWeight,
      'instructionContext': instructionContext,
    };
    const TrainingReportSyncPayloadSchema().validateRequest(payload);
    return payload;
  }
}

class MorningBriefRequestPayloadBuilder {
  const MorningBriefRequestPayloadBuilder();

  Map<String, Object?> build({
    required String operationDate,
    required MorningFact fact,
    Object? carryover,
    Object? previousDaySummary,
    Object? recentTrend,
    Object? availableStrategicResources,
    Object? generationRequirements,
  }) {
    final payload = <String, Object?>{
      'operationDate': operationDate,
      'morningFact': {
        'body': {'weightKg': fact.weight, 'bodyFatPercent': fact.bodyFat},
        'recovery': {
          'sleepDurationMinutes': fact.sleepDuration?.inMinutes,
          'sleepScore': fact.sleepScore,
        },
        'condition': {
          'footPainLevel': fact.footPain,
          'reportedConditions': <Object?>[],
        },
        'work': {'workStatus': null, 'startTime': null, 'endTime': null},
        'carryover': fact.previousCarryoverConfirmed,
      },
      'carryover': carryover,
      'previousDaySummary': previousDaySummary,
      'recentTrend': recentTrend,
      'availableStrategicResources': availableStrategicResources,
      'generationRequirements': generationRequirements,
    };
    const MorningBriefReportSyncPayloadSchema().validateRequest(payload);
    return payload;
  }
}
