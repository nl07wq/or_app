import 'dart:convert';

import '../../../core/models/cardio_entry.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../../training/sync/training_sync_schema.dart';
import '../models/report_sync_envelope.dart';
import 'report_sync_payload_registry.dart';

abstract interface class ReportSyncInstructionProvider {
  ReportSyncExchangeType get exchangeType;

  String buildInstruction({
    String operationDate = '<OPERATION_DATE>',
    String? confirmationDigest,
  });
}

class StandardReportSyncInstructionProvider
    implements ReportSyncInstructionProvider {
  @override
  final ReportSyncExchangeType exchangeType;
  final ReportSyncPayloadSchema schema;
  const StandardReportSyncInstructionProvider(this.exchangeType, this.schema);

  @override
  String buildInstruction({
    String operationDate = '<OPERATION_DATE>',
    String? confirmationDigest,
  }) {
    if (exchangeType == ReportSyncExchangeType.dailyDebrief &&
        confirmationDigest == null) {
      throw StateError('Daily Debrief requires a confirmation digest.');
    }
    final payload = Map<String, Object?>.from(schema.minimalResponseExample);
    payload['operationDate'] = operationDate;
    if (confirmationDigest != null) {
      payload['confirmationDigest'] = confirmationDigest;
    }
    final responseExample = <String, Object?>{
      'format': ReportSyncEnvelope.formatId,
      'envelopeVersion': ReportSyncEnvelope.currentEnvelopeVersion,
      'schemaVersion': ReportSyncEnvelope.currentSchemaVersion,
      'direction': ReportSyncDirection.response.stableId,
      'exchangeType': exchangeType.stableId,
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'operationDate': operationDate,
      'createdAt': '<UTC_TIMESTAMP>',
      'confirmationDigest': confirmationDigest,
      'payload': payload,
      'packageDigest':
          '0000000000000000000000000000000000000000000000000000000000000000',
    };
    return '''
${_purpose(operationDate)}

SOURCE CONTRACT
The next user message contains exactly one $_sourceName. This prompt is not source data. Analyze only the $_sourceName pasted after this prompt. Do not use another record type or data from another date.
${_sourceRules()}
${_fieldRules(confirmationDigest)}

RESPONSE CONTRACT
Return exactly one JSON object for Operation Reboot $_schemaName.
Return JSON only. Do not return Markdown, code fences, comments, headings, or explanatory text before or after JSON. Do not return multiple JSON values.
Use format "${ReportSyncEnvelope.formatId}", envelopeVersion 1, schemaVersion "1.0", direction "response", exchangeType "${exchangeType.stableId}", and operationDate "$operationDate" exactly.
Do not add unknown fields or sections. Do not convert numbers to strings. Preserve null separately from numeric zero and do not convert null to an empty string.
Do not invent facts, infer missing facts, mix another date, or generate values absent from the source. Use only the allowed stable IDs shown by the schema.
Create a unique exchangeId and a UTC createdAt timestamp. The packageDigest must be lowercase SHA-256 over canonical JSON of the complete envelope excluding packageDigest itself. Do not hash the prompt or source text.

The complete response field structure is shown below. Placeholder values describe types only and are not facts. Replace every placeholder from the supplied $_sourceName; use null only where the schema permits it.
${const JsonEncoder.withIndent('  ').convert(responseExample)}
'''
        .trim();
  }

  String _purpose(String date) => switch (exchangeType) {
    ReportSyncExchangeType.training =>
      'Convert the Training Record pasted after this prompt for $date into Operation Reboot Training Import Schema Version 1.',
    ReportSyncExchangeType.food =>
      'Convert the Meal Data pasted after this prompt for $date into Operation Reboot Food Import Schema Version 1.',
    ReportSyncExchangeType.morningBrief =>
      'Use the Morning Fact pasted after this prompt for $date to generate Operation Reboot Morning Brief Import Schema Version 1.',
    ReportSyncExchangeType.dailyDebrief =>
      'Use the Finalized Daily Data pasted after this prompt for $date to generate Operation Reboot Daily Debrief Import Schema Version 1.',
  };

  String get _sourceName => switch (exchangeType) {
    ReportSyncExchangeType.training => 'Training Record',
    ReportSyncExchangeType.food => 'Meal Data',
    ReportSyncExchangeType.morningBrief => 'Morning Fact',
    ReportSyncExchangeType.dailyDebrief => 'Finalized Daily Data',
  };

  String get _schemaName => switch (exchangeType) {
    ReportSyncExchangeType.training => 'Training Import Schema Version 1',
    ReportSyncExchangeType.food => 'Food Import Schema Version 1',
    ReportSyncExchangeType.morningBrief =>
      'Morning Brief Import Schema Version 1',
    ReportSyncExchangeType.dailyDebrief =>
      'Daily Debrief Import Schema Version 1',
  };

  String _sourceRules() => switch (exchangeType) {
    ReportSyncExchangeType.training =>
      'Convert only recorded exercises, sets, and cardio entries. Preserve their order. Do not create an exercise, infer equipment, invent evaluation or next target, or fill a numeric value missing from the record. Return only Training import JSON.',
    ReportSyncExchangeType.food =>
      'Convert only recorded meals and food items. Do not infer nutrition, convert null to zero, register Food Catalog or Recipe data, convert implicitly to Daily Meal v2, infer reference or provenance, or create an unrecorded meal. Return only Food import JSON.',
    ReportSyncExchangeType.morningBrief =>
      'Use only formal Body, Recovery, Condition, Work, and Carryover facts. Bowel information is out of scope. Do not complete a missing fact. operationStatus must be green, yellow, or red. Generate one-sentence commanderIntent plus situationAnalysis, argoComment, strategicResourceDecision, and actions from supplied facts only. Return only Morning Brief import JSON.',
    ReportSyncExchangeType.dailyDebrief =>
      'Use only finalized facts. Use Morning Brief only when included. Do not complete unconfirmed information or alter Confirmation or Snapshot facts. Produce commanderIntentEvaluation, dailySummary, successes, issues, nutritionEvaluation, activityEvaluation, trainingEvaluation, recoveryEvaluation, carryover, and tomorrowConsiderations. The confirmationDigest is fixed by the schema and must not change. Return only Daily Debrief import JSON.',
  };

  String _fieldRules(String? confirmationDigest) => switch (exchangeType) {
    ReportSyncExchangeType.training =>
      'Training session fields: ${TrainingSyncSchema.sessionFields.join(', ')}. Exercise fields: ${TrainingSyncSchema.exerciseFields.join(', ')}. Equipment fields: ${TrainingSyncSchema.equipmentFields.join(', ')}. Set fields: ${TrainingSyncSchema.setFields.join(', ')}. Cardio fields: ${TrainingSyncSchema.cardioFields.join(', ')}. Allowed grade stable IDs: ${TrainingSessionGrade.values.map((value) => value.stableId).join(', ')}. Allowed set type stable IDs: ${TrainingSetType.values.where((value) => value != TrainingSetType.legacyUnknown).map((value) => value.stableId).join(', ')}. Allowed cardio purpose stable IDs: ${CardioPurpose.values.where((value) => value != CardioPurpose.legacyUnknown).map((value) => value.stableId).join(', ')}. Allowed cardio type stable IDs: ${CardioType.values.map((value) => value.name).join(', ')}. legacyUnknown is forbidden. Nullable fields must be null when the source has no value.',
    ReportSyncExchangeType.food =>
      'Every meal contains exactly mealId, mealType, items, memo, and waterMl. Every food item contains exactly name, calories, protein, fat, carbohydrate, quantity, amount, baseAmount, baseUnit, and amountMode. Preserve the mealType recorded in the source; do not translate or invent a stable ID. Nullable fields must be null when unrecorded.',
    ReportSyncExchangeType.morningBrief =>
      'The content fields are situationAnalysis, operationStatus, commanderIntent, argoComment, strategicResourceDecision, and actions. Each action contains actionId, text, and priority. The allowed operationStatus stable IDs are green, yellow, and red.',
    ReportSyncExchangeType.dailyDebrief =>
      'The content fields are dailySummary, commanderIntentEvaluation, successes, issues, nutritionEvaluation, activityEvaluation, trainingEvaluation, recoveryEvaluation, carryover, and tomorrowConsiderations. The fixed confirmationDigest is $confirmationDigest.',
  };
}

class ReportSyncInstructionProviderRegistry {
  final Map<ReportSyncExchangeType, ReportSyncInstructionProvider> _providers;
  ReportSyncInstructionProviderRegistry(
    Iterable<ReportSyncInstructionProvider> providers,
  ) : _providers = {
        for (final provider in providers) provider.exchangeType: provider,
      } {
    if (_providers.length != ReportSyncExchangeType.values.length) {
      throw StateError('All REPORT SYNC instruction providers are required.');
    }
  }

  factory ReportSyncInstructionProviderRegistry.standard() =>
      ReportSyncInstructionProviderRegistry([
        for (final type in ReportSyncExchangeType.values)
          StandardReportSyncInstructionProvider(
            type,
            ReportSyncPayloadRegistry.standard().forType(type),
          ),
      ]);

  ReportSyncInstructionProvider forType(ReportSyncExchangeType type) =>
      _providers[type]!;
}
