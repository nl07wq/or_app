import 'dart:convert';

import '../../../core/models/cardio_entry.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../../training/sync/training_sync_schema.dart';
import '../models/report_sync_envelope.dart';
import 'report_sync_payload_registry.dart';
import 'report_sync_import_schema_v2.dart';

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
    final importSchema2 =
        exchangeType == ReportSyncExchangeType.training ||
        exchangeType == ReportSyncExchangeType.food;
    final payload = Map<String, Object?>.from(
      exchangeType == ReportSyncExchangeType.training
          ? const TrainingReportSyncPayloadSchemaV2().minimalResponseExample
          : exchangeType == ReportSyncExchangeType.food
          ? const FoodReportSyncPayloadSchemaV2().minimalResponseExample
          : schema.minimalResponseExample,
    );
    payload['operationDate'] = operationDate;
    if (exchangeType == ReportSyncExchangeType.training) {
      final session = Map<String, Object?>.from(payload['session'] as Map);
      final header = Map<String, Object?>.from(session['session'] as Map);
      header['localDate'] = operationDate;
      session['session'] = header;
      payload['session'] = session;
    }
    if (confirmationDigest != null) {
      payload['confirmationDigest'] = confirmationDigest;
    }
    final responseExample = <String, Object?>{
      'format': ReportSyncEnvelope.formatId,
      'envelopeVersion': ReportSyncEnvelope.currentEnvelopeVersion,
      'schemaVersion': importSchema2
          ? ReportSyncEnvelope.importSchemaVersion2
          : ReportSyncEnvelope.currentSchemaVersion,
      'direction': ReportSyncDirection.response.stableId,
      'exchangeType': exchangeType.stableId,
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'operationDate': operationDate,
      'createdAt': '<UTC_TIMESTAMP>',
      'confirmationDigest': confirmationDigest,
      'payload': payload,
      'packageDigest': importSchema2 ? null : _legacyDigestPlaceholder,
    };
    if (exchangeType == ReportSyncExchangeType.training ||
        exchangeType == ReportSyncExchangeType.food) {
      return _buildImportOnlyInstruction(
        operationDate,
        responseExample,
        confirmationDigest,
      );
    }
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

  String _buildImportOnlyInstruction(
    String operationDate,
    Map<String, Object?> responseExample,
    String? confirmationDigest,
  ) {
    final isFood = exchangeType == ReportSyncExchangeType.food;
    final retainedData = isFood ? 'all Meal Data records' : 'Training Record';
    final completeness = isFood
        ? 'Return every meal for the target date in payload.meals. Keep each meal and each item separate. Do not merge meals, create a daily aggregate, omit a meal, or return an empty meals array.'
        : 'Return exactly one Training response. Preserve every recorded exercise, set, and cardio entry in its recorded order.';
    return '''
Create an Operation Reboot ${isFood ? 'Food' : 'Training'} REPORT SYNC response for $operationDate using $retainedData that you already retain from this conversation or its available context.

SOURCE CONTRACT
This prompt is not source data. Operation Reboot will not send another source record after this prompt. Use only the formal $retainedData already retained for exactly $operationDate. If that source is not available, do not fabricate an import response.
$completeness
${_sourceRules()}
${_fieldRules(confirmationDigest)}

RESPONSE CONTRACT
Return exactly one JSON object for Operation Reboot $_schemaName.
Return exactly one fenced Plain Text code block whose opening fence is ```text and whose closing fence is ```.
Inside that code block, return only the single import JSON object. Do not include explanations, headings, greetings, notes, list items, JSON start/end markers, comments, or multiple JSON values. Do not return any text outside the code block. Do not use a json code-block label.
The user will use ChatGPT's copy button to copy the complete code-block content and paste that JSON directly into Operation Reboot. The copied content must therefore start with { and end with } without the fences.
Use only ASCII half-width double quotation marks (U+0022). Smart quotes and typographic quotation marks are forbidden.
Use format "${ReportSyncEnvelope.formatId}", envelopeVersion 1, schemaVersion "2.0", direction "response", exchangeType "${exchangeType.stableId}", and operationDate "$operationDate" exactly.
Do not add unknown fields or sections. Do not convert numbers to strings. Preserve null separately from numeric zero and do not convert null to an empty string.
Do not invent facts, infer missing facts, mix another date, or generate values absent from the retained record. Use only the allowed stable IDs shown by the schema.
Create a unique exchangeId and a UTC createdAt timestamp. Set packageDigest to null. Do not calculate a digest and do not replace null with a placeholder or any string. Operation Reboot calculates the formal digest after strict validation.

The complete response field structure is shown below. Placeholder values describe types only and are not facts. Replace every placeholder from the retained record; use null only where the schema permits it.
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
    ReportSyncExchangeType.training => 'Training Import Schema Version 2',
    ReportSyncExchangeType.food => 'Food Import Schema Version 2',
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
      'Do not create recordId, idempotencyKey, or exerciseId. sourceRecordId is the original reference ID when known, otherwise null; it is never the storage ID. nextTarget must be a String or null. equipment.id must be a String or null and equipment.name must be recorded text. Internal IDs are generated by Operation Reboot. Set fields: ${TrainingSyncSchema.setFields.join(', ')}. Cardio fields: ${TrainingSyncSchema.cardioFields.join(', ')}. A Cardio Calories Snapshot must contain all four fields together: estimatedCaloriesKcal must be a finite number greater than or equal to zero, weightSnapshotKg must be a finite positive number, calculationMethod must be metsAcsmV1, and calculationVersion must be 1. estimatedCaloriesKcal must exactly match mets * 3.5 * weightSnapshotKg / 200 * (durationSeconds / 60) without independent rounding. If the formal source does not contain a complete snapshot, or its calculation weight cannot be confirmed, set all four fields to null. Never copy calories alone while leaving the other snapshot fields null, infer weight, or reconstruct a snapshot from a recorded calories value. Allowed grade stable IDs: ${TrainingSessionGrade.values.map((value) => value.stableId).join(', ')}. Allowed set type stable IDs: ${TrainingSetType.values.where((value) => value != TrainingSetType.legacyUnknown).map((value) => value.stableId).join(', ')}. Allowed cardio purpose stable IDs: ${CardioPurpose.values.where((value) => value != CardioPurpose.legacyUnknown).map((value) => value.stableId).join(', ')}. Allowed cardio type stable IDs: ${CardioType.values.map((value) => value.name).join(', ')}. legacyUnknown is forbidden. Nullable fields must be null when the source has no value.',
    ReportSyncExchangeType.food =>
      'Do not create mealId or any internal ID. Every meal contains exactly sourceMealId, mealType, items, memo, and waterMl. sourceMealId is the original reference ID only when it can be confirmed, otherwise null. Every food item contains exactly name, calories, protein, fat, carbohydrate, quantity, amount, baseAmount, baseUnit, and amountMode. quantity is the recorded count multiplier and must be an integer of 1 or greater. amount and baseAmount must be finite positive numbers when present. amount, baseAmount, and baseUnit are one measurement tuple: provide all three together or set all three to null. Allowed baseUnit values are g and mL. Allowed amountMode values are physicalAmount and baseMultiplier; amountMode may be null only when it was not recorded, and a non-null amountMode requires the complete measurement tuple. For physicalAmount, amount is the consumed physical amount and the nutrition multiplier is amount divided by baseAmount. For baseMultiplier, amount is the recorded multiplier and the consumed physical amount is baseAmount multiplied by amount. When the measurement tuple is present, calories, protein, fat, and carbohydrate are the recorded nutrition basis corresponding to baseAmount, not consumed totals. Do not infer a missing measurement field, mode, unit, count, or nutrition value. Keep multiple meals separate. Operation Reboot generates permanent Meal IDs. Preserve the recorded mealType. Nullable fields must be null when unrecorded.',
    ReportSyncExchangeType.morningBrief =>
      'The content fields are situationAnalysis, operationStatus, commanderIntent, argoComment, strategicResourceDecision, and actions. Each action contains actionId, text, and priority. The allowed operationStatus stable IDs are green, yellow, and red.',
    ReportSyncExchangeType.dailyDebrief =>
      'The content fields are dailySummary, commanderIntentEvaluation, successes, issues, nutritionEvaluation, activityEvaluation, trainingEvaluation, recoveryEvaluation, carryover, and tomorrowConsiderations. The fixed confirmationDigest is $confirmationDigest.',
  };

  static const _legacyDigestPlaceholder =
      '0000000000000000000000000000000000000000000000000000000000000000';
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
