import 'dart:convert';

import '../../../core/models/cardio_entry.dart';
import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../../training/sync/training_sync_schema.dart';
import '../models/report_sync_envelope.dart';
import '../models/daily_debrief_record.dart';
import 'report_sync_payload_registry.dart';
import 'report_sync_import_schema_v2.dart';

abstract interface class ReportSyncInstructionProvider {
  ReportSyncExchangeType get exchangeType;

  String buildInstruction({
    String operationDate = '<OPERATION_DATE>',
    String? confirmationDigest,
    String? sourceRecordId,
    String? sourceDigest,
    DailyDebriefSources? dailyDebriefSources,
    Map<String, Object?>? dailyDebriefSource,
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
    String? sourceRecordId,
    String? sourceDigest,
    DailyDebriefSources? dailyDebriefSources,
    Map<String, Object?>? dailyDebriefSource,
  }) {
    if (exchangeType == ReportSyncExchangeType.dailyDebrief) {
      if (dailyDebriefSources == null || dailyDebriefSource == null) {
        throw StateError('Daily Debrief requires formal source data.');
      }
      return _buildDailyDebriefInstruction(
        operationDate,
        dailyDebriefSources,
        dailyDebriefSource,
      );
    }
    if (exchangeType == ReportSyncExchangeType.morningBrief) {
      if (sourceRecordId == null || sourceDigest == null) {
        throw StateError('Morning Brief requires STATUS source identity.');
      }
      return _buildMorningBriefInstruction(
        operationDate,
        sourceRecordId,
        sourceDigest,
      );
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

  String _buildDailyDebriefInstruction(
    String operationDate,
    DailyDebriefSources sources,
    Map<String, Object?> source,
  ) {
    final hasMorningBrief = sources.morningBrief != null;
    final analysis = <String, Object?>{
      'commanderIntentEvaluation': hasMorningBrief
          ? {
              'outcome': 'achieved',
              'rationale': '<Japanese non-empty analysis>',
              'evidence': <Object?>[],
            }
          : null,
      'domainEvaluations': {
        'body': '<Japanese analysis or null>',
        'recovery': '<Japanese analysis or null>',
        'condition': '<Japanese analysis or null>',
        'work': '<Japanese analysis or null>',
        'nutrition': '<Japanese analysis or null>',
        'hydration': '<Japanese analysis or null>',
        'activity': '<Japanese analysis or null>',
        'training': null,
      },
      'crossAnalysis': {
        'keyFactors': <Object?>[],
        'interactions': <Object?>[],
        'constraints': <Object?>[],
        'resources': <Object?>[],
      },
      'executionEvaluation': {
        'successes': <Object?>[],
        'adjustments': <Object?>[],
      },
      'nextDayHandoff': {'watchPoints': <Object?>[]},
    };
    final response = <String, Object?>{
      'format': ReportSyncEnvelope.formatId,
      'envelopeVersion': ReportSyncEnvelope.currentEnvelopeVersion,
      'schemaVersion': ReportSyncEnvelope.importSchemaVersion2,
      'direction': ReportSyncDirection.response.stableId,
      'exchangeType': ReportSyncExchangeType.dailyDebrief.stableId,
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'operationDate': operationDate,
      'createdAt': '<UTC_TIMESTAMP>',
      'confirmationDigest': null,
      'payload': {
        'operationDate': operationDate,
        'recordVersion': DailyDebriefRecord.currentRecordVersion,
        'sources': sources.toJson(),
        'analysis': analysis,
      },
      'packageDigest': null,
    };
    return '''
Create the formal Operation Reboot DAILY DEBRIEF for $operationDate.

SOURCE CONTRACT
Use only the FORMAL SOURCE JSON below. DAILY AGGREGATE is the sole fact source. CONFIRMATION is identity and lifecycle metadata only; do not use its snapshot as another fact source. MORNING BRIEF, when present, supplies only OPERATION STATUS, COMMANDER INTENT, and ACTIONS. Do not use another date, Daily Assessment, History Context, or legacyDns data.
Preserve every source fact exactly. Do not recalculate nutrition, expenditure, calorie balance, steps, body changes, digestive data, or any other fact. Preserve null as null. Do not infer or complete missing facts.
Analyze relationships across domains instead of merely repeating or re-listing source values. Cite only the facts needed as evidence, and center each domain evaluation on what those facts support. Do not infer trends from a single value or invent events, feelings, causes, or outcomes that the FORMAL SOURCE JSON does not confirm. Treat anything unsupported by the source as not confirmed.
In human-readable analysis text, use natural Japanese descriptions rather than exposing internal field identifiers or raw boolean expressions such as trainingPerformed=false or officialSteps. Do not change their meaning, and keep all schema field names unchanged in the JSON structure and sources object.
Compare Morning Brief intent with execution only when Morning Brief exists. When Morning Brief is absent, commanderIntentEvaluation must be null. DOMAIN EVALUATIONS body, recovery, condition, work, nutrition, hydration, activity, and training are each string or null. When a domain has no formal fact to evaluate, its evaluation must be explicit null; do not turn absence into prose such as not performed, none, no problem, good, or not assessable. In particular, when trainingPerformed is false and there is no formal Training fact to evaluate, domainEvaluations.training must be null. The false fact may still support cross-analysis against a Morning Brief instruction to avoid additional training load, but it must not create a Training domain evaluation.
In human-readable analysis text only, format quoted numeric facts at a natural display precision and remove apparent floating-point artifacts. For example, render 62.06999999999999 as 62.07g, 295.53999999999996 as 295.54g, and -355.5999999999999 as -355.6kcal. Keep naturally integral facts such as steps, hydration mL, sleep minutes, and work minutes integral. Respect meaningful source precision; do not force every number to an integer or to one decimal place. This formatting applies only to analysis prose: do not alter, round, recalculate, estimate, or re-save any FORMAL SOURCE JSON value, and do not change or recalculate any source digest.
executionEvaluation.adjustments must contain only actionable improvements supported by formal facts and analysis. Do not add an item merely saying that something cannot be confirmed or evaluated. nextDayHandoff.watchPoints may contain only fact-supported matters worth checking in the next Morning Routine; it must not decide the next-day operation or create carryover.
Do not create dailySummary, overallSummary, debriefSummary, executionSummary, carryover, Commander Intent, next-day actions, or priorities. nextDayHandoff contains WATCH POINTS only.

RESPONSE CONTRACT
Return exactly one fenced Plain Text code block whose opening fence is ```text and whose closing fence is ```. Return nothing outside that code block: no explanation, heading, greeting, note, preface, afterword, or additional code block. Inside the code block, return exactly one JSON object and no prose, comments, headings, or multiple JSON values. The user will use ChatGPT's code-block copy action; the copied content must start with { and end with } without the fences.
Use only ASCII half-width double quotation marks (U+0022) for JSON syntax. Never use smart or curly quotes such as “ ” or ‘ ’. Use the exact COMPLETE RESPONSE SHAPE with schemaVersion "2.0", recordVersion 1, exchangeType "dailyDebrief", operationDate "$operationDate", confirmationDigest null, and packageDigest null. Preserve the sources object below exactly in field content and values. Do not add unknown fields, remove fields, rename fields, omit required fields, or add schema-external sections. Nullable fields must be explicit null. Required array fields must be present and use [] when empty. Every string and array item must be non-empty after trimming. Use only these outcome values: achieved, partiallyAchieved, notAchieved, notAssessable.
Before returning, internally verify that the JSON is syntactically complete and structurally matches the exact schema: the root contains exactly one object; object and array nesting is balanced; every opening brace, bracket, and ASCII quote has its matching closing character; there is no extra or missing closing brace; there is no trailing comma; every required field exists; and no unknown field exists. Do not output this verification process or a checklist. The final response must contain only the verified JSON object inside the single Plain Text code block.

FORMAL SOURCE JSON
${const JsonEncoder.withIndent('  ').convert(source)}

COMPLETE RESPONSE SHAPE
${const JsonEncoder.withIndent('  ').convert(response)}
'''
        .trim();
  }

  String _buildMorningBriefInstruction(
    String operationDate,
    String sourceRecordId,
    String sourceDigest,
  ) {
    final responseExample = <String, Object?>{
      'format': ReportSyncEnvelope.formatId,
      'envelopeVersion': ReportSyncEnvelope.currentEnvelopeVersion,
      'schemaVersion': ReportSyncEnvelope.importSchemaVersion2,
      'direction': ReportSyncDirection.response.stableId,
      'exchangeType': ReportSyncExchangeType.morningBrief.stableId,
      'exchangeId': '<UNIQUE_RESPONSE_ID>',
      'operationDate': operationDate,
      'createdAt': '<UTC_TIMESTAMP>',
      'confirmationDigest': null,
      'payload': {
        'operationDate': operationDate,
        'source': {
          'sourceType': 'status',
          'sourceOperationDate': operationDate,
          'sourceRecordId': sourceRecordId,
          'sourceDigest': sourceDigest,
        },
        'content': {
          'situationAnalysis': {
            'body': '<Japanese plain text>',
            'bodyDisplay': {
              'primaryText': '<Japanese plain text>',
              'supportingText': '<Japanese plain text or null>',
            },
            'recovery': '<Japanese plain text>',
            'recoveryDisplay': {
              'primaryText': '<Japanese plain text>',
              'supportingText': '<Japanese plain text or null>',
            },
            'condition': '<Japanese plain text>',
            'conditionDisplay': {
              'primaryText': '<Japanese plain text>',
              'supportingText': '<Japanese plain text or null>',
            },
            'work': '<Japanese plain text>',
            'workDisplay': {
              'primaryText': '<Japanese plain text>',
              'supportingText': '<Japanese plain text or null>',
            },
            'carryover': '<Japanese plain text>',
            'overall': '<Japanese plain text>',
          },
          'operatingPolicy': '<Japanese plain text>',
          'strategicResourceDecision': {
            'decision': '<Japanese plain text>',
            'targetResource': null,
            'rationale': '<Japanese plain text>',
            'execution': null,
          },
          'operationStatus': 'green',
          'commanderIntent': '<Japanese one-line sentence>',
          'actions': [
            {'text': '<Japanese one-line action>', 'priority': 'high'},
          ],
        },
      },
      'packageDigest': null,
    };
    return '''
Operation Rebootの$operationDateの正式なMORNING BRIEFを生成してください。

SOURCE CONTRACT
このPrompt自体はSource Dataではありません。末尾のSOURCE DATA STARTとSOURCE DATA ENDの間にある、同日かつsourceRecordIdが「$sourceRecordId」、sourceDigestが「$sourceDigest」の正式なSTATUS SOURCEだけを使用してください。
別日、別Record、会話中の別情報、不足情報の推測を混ぜないでください。本文は日本語のPlain Textとし、候補ではなく当日の正式な判断を返してください。必須Sectionをすべて出力してください。

RESPONSE CONTRACT
返答全体は、開始Fenceが```text、終了Fenceが```の単一のPlain Textコードブロック1つだけにしてください。コードブロック内には単一のImport用JSON Objectだけを入れ、コードブロック外には説明、見出し、挨拶、注記を一切出力しないでください。コピーされる内容は{で始まり}で終わる必要があります。
formatは「${ReportSyncEnvelope.formatId}」、envelopeVersionは1、schemaVersionは「2.0」、directionは「response」、exchangeTypeは「morningBrief」、operationDateは「$operationDate」に固定してください。
packageDigestはnullにしてください。Digestを計算せず、Placeholderや文字列へ置換しないでください。アプリがStrict Validation後に正式Digestを生成します。
Unknown Field、旧Schema 1.0 Field、argoComment、actionIdを追加しないでください。situationAnalysisを単一Stringにしないでください。
situationAnalysisのbody/recovery/condition/work/carryover/overallと、bodyDisplay/recoveryDisplay/conditionDisplay/workDisplay、operatingPolicy、strategicResourceDecision、operationStatus、commanderIntent、actionsをすべて返してください。
body/recovery/condition/workは従来どおりSection全体の日本語分析文です。各DisplayはprimaryTextとsupportingTextだけを持ち、primaryTextにはSTATUS SOURCEの明示Fact、supportingTextには対応する分析文だけを入れてください。Factと分析を後から文字列分割できる形式へ連結しないでください。
bodyDisplay.primaryTextは「体重: 値kg  体脂肪率: 値%」形式とし、前日比とBody分析はbodyDisplay.supportingTextへ入れてください。
recoveryDisplay.primaryTextは「睡眠時間: H:MM  睡眠スコア: 値」形式とし、sleepDurationMinutesをH:MMへ変換してください。sleepScoreがnullの場合は0へ変換せず「睡眠スコア: 仮眠」としてください。Recovery分析はrecoveryDisplay.supportingTextへ入れてください。
conditionDisplay.primaryTextは「足底筋膜炎: LV.n」形式とし、FOOT PAIN LEVELの数値を使用してください。Condition分析はconditionDisplay.supportingTextへ入れてください。
workDisplay.primaryTextはSTATUS SOURCEに存在する勤務Factだけを「項目名: 値」で表し、存在しない勤務情報を推測しないでください。Work補足がない場合のみworkDisplay.supportingTextをnullにしてください。
STRATEGIC RESOURCE DECISIONで睡眠時間を使用する場合も、sleepDurationMinutesをH:MMへ変換した自然な日本語にしてください。「151分」のような分表記を使用しないでください。
operationStatusはgreen/yellow/redのみです。commanderIntentは日本語1行で、「候補」という表現を付けないでください。actionsは1件以上5件以下、入力順を維持し、各要素はtextとpriorityだけにしてください。priorityはlow/medium/high/criticalのみです。actionIdはアプリが生成します。
decisionとrationaleは日本語Plain Text必須、targetResourceとexecutionは情報がない場合だけnullです。Markdown、改行付きCommander Intent、型変換、Missing Field補完は禁止です。

完全なResponse構造は次のとおりです。Placeholderは型の説明であり事実ではありません。
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
      'Prepare the formal STATUS Source for Morning Brief review on $date.',
    ReportSyncExchangeType.dailyDebrief =>
      'Prepare the formal DAILY DEBRIEF analysis for $date.',
  };

  String get _sourceName => switch (exchangeType) {
    ReportSyncExchangeType.training => 'Training Record',
    ReportSyncExchangeType.food => 'Meal Data',
    ReportSyncExchangeType.morningBrief => 'STATUS Source',
    ReportSyncExchangeType.dailyDebrief => 'DAILY AGGREGATE Source',
  };

  String get _schemaName => switch (exchangeType) {
    ReportSyncExchangeType.training => 'Training Import Schema Version 2',
    ReportSyncExchangeType.food => 'Food Import Schema Version 2',
    ReportSyncExchangeType.morningBrief => 'Morning Brief source review',
    ReportSyncExchangeType.dailyDebrief => 'Daily Debrief Schema Version 1',
  };

  String _sourceRules() => switch (exchangeType) {
    ReportSyncExchangeType.training =>
      'Convert only recorded exercises, sets, and cardio entries. Preserve their order. Do not create an exercise, infer equipment, invent evaluation or next target, or fill a numeric value missing from the record. Return only Training import JSON.',
    ReportSyncExchangeType.food =>
      'Convert only recorded meals and food items. Do not infer nutrition, convert null to zero, register Food Catalog or Recipe data, convert implicitly to Daily Meal v2, infer reference or provenance, or create an unrecorded meal. Return only Food import JSON.',
    ReportSyncExchangeType.morningBrief =>
      'Use only formal Body, Previous Day Comparison, Recovery, Condition, Work, and Carryover facts. Bowel information is out of scope. Do not complete a missing fact.',
    ReportSyncExchangeType.dailyDebrief =>
      'Use only the formal Daily Debrief source projection.',
  };

  String _fieldRules(String? confirmationDigest) => switch (exchangeType) {
    ReportSyncExchangeType.training =>
      'Do not create recordId, idempotencyKey, or exerciseId. sourceRecordId is the original reference ID when known, otherwise null; it is never the storage ID. nextTarget must be a String or null. equipment.id must be a String or null and equipment.name must be recorded text. Internal IDs are generated by Operation Reboot. Set fields: ${TrainingSyncSchema.setFields.join(', ')}. Cardio fields: ${TrainingSyncSchema.cardioFields.join(', ')}. Preserve startTime and endTime only when formally recorded as offset ISO-8601 datetimes; otherwise set both to null and never infer them. A Strength Calories Snapshot must contain estimatedStrengthCaloriesKcal, strengthWeightSnapshotKg, strengthCalculationMethod=strengthSessionMetsAcsmV1, and strengthCalculationVersion=1 together, or all four must be null. Never infer or reconstruct it. A Cardio Calories Snapshot must contain all four fields together: estimatedCaloriesKcal must be a finite number greater than or equal to zero, weightSnapshotKg must be a finite positive number, calculationMethod must be metsAcsmV1, and calculationVersion must be 1. estimatedCaloriesKcal must exactly match mets * 3.5 * weightSnapshotKg / 200 * (durationSeconds / 60) without independent rounding. If the formal source does not contain a complete snapshot, or its calculation weight cannot be confirmed, set all four formal snapshot fields to null. Never copy calories alone while leaving the other snapshot fields null, infer weight, or reconstruct a snapshot from a recorded calories value. Allowed grade stable IDs: ${TrainingSessionGrade.values.map((value) => value.stableId).join(', ')}. Allowed set type stable IDs: ${TrainingSetType.values.where((value) => value != TrainingSetType.legacyUnknown).map((value) => value.stableId).join(', ')}. Allowed cardio purpose stable IDs: ${CardioPurpose.values.where((value) => value != CardioPurpose.legacyUnknown).map((value) => value.stableId).join(', ')}. Allowed cardio type stable IDs: ${CardioType.values.map((value) => value.name).join(', ')}. legacyUnknown is forbidden. Nullable fields must be null when the source has no value.',
    ReportSyncExchangeType.food =>
      'Do not create mealId or any internal ID. Every meal contains exactly sourceMealId, mealType, items, memo, and waterMl. sourceMealId is the original reference ID only when it can be confirmed, otherwise null. Every food item contains exactly name, calories, protein, fat, carbohydrate, quantity, amount, baseAmount, baseUnit, and amountMode. quantity is the recorded count multiplier and must be an integer of 1 or greater. amount and baseAmount must be finite positive numbers when present. amount, baseAmount, and baseUnit are one measurement tuple: provide all three together or set all three to null. Allowed baseUnit values are g and mL. Allowed amountMode values are physicalAmount and baseMultiplier; amountMode may be null only when it was not recorded, and a non-null amountMode requires the complete measurement tuple. For physicalAmount, amount is the consumed physical amount and the nutrition multiplier is amount divided by baseAmount. For baseMultiplier, amount is the recorded multiplier and the consumed physical amount is baseAmount multiplied by amount. When the measurement tuple is present, calories, protein, fat, and carbohydrate are the recorded nutrition basis corresponding to baseAmount, not consumed totals. Do not infer a missing measurement field, mode, unit, count, or nutrition value. Keep multiple meals separate. Operation Reboot generates permanent Meal IDs. Preserve the recorded mealType. Nullable fields must be null when unrecorded.',
    ReportSyncExchangeType.morningBrief =>
      'Return the formal Morning Brief Schema Version 2 response only.',
    ReportSyncExchangeType.dailyDebrief =>
      'Return the formal Daily Debrief Schema Version 1 payload only.',
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
