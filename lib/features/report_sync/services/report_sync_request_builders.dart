import '../../../core/models/daily_log_confirmation.dart';
import '../../morning/models/morning_fact.dart';
import 'report_sync_canonical_service.dart';
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

class DailyDebriefRequestPayloadBuilder {
  const DailyDebriefRequestPayloadBuilder();

  Map<String, Object?> build({
    required String operationDate,
    required DailyLogConfirmation confirmation,
    required Map<String, Object?> finalizedSnapshot,
    Object? morningBrief,
    Object? commanderIntent,
    Object? generationRequirements,
  }) {
    final confirmationJson = Map<String, Object?>.from(confirmation.toJson());
    final digest = ReportSyncCanonicalService.digest(confirmationJson);
    final payload = <String, Object?>{
      'operationDate': operationDate,
      'confirmationDigest': digest,
      'confirmation': confirmationJson,
      'finalizedSnapshot': finalizedSnapshot,
      'morningBrief': morningBrief,
      'commanderIntent': commanderIntent,
      'generationRequirements': generationRequirements,
    };
    const DailyDebriefReportSyncPayloadSchema().validateRequest(payload);
    return payload;
  }
}
