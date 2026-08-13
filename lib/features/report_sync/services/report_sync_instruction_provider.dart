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
    Map<String, Object?>? recentContext,
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
    Map<String, Object?>? recentContext,
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
        throw StateError('Daily Brief requires STATUS source identity.');
      }
      return _buildMorningBriefInstruction(
        operationDate,
        sourceRecordId,
        sourceDigest,
        recentContext ?? const <String, Object?>{},
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
    return '''
Create the formal Operation Reboot DAILY DEBRIEF for $operationDate.

SOURCE CONTRACT
Use only the FORMAL SOURCE JSON below. DAILY AGGREGATE is the current-day fact source. RECENT CONTEXT is derived mechanically from records-source Daily Aggregates in the D-6 through D window and is supporting context only. CONFIRMATION is identity and lifecycle metadata only; do not use its snapshot as another fact source. DAILY BRIEF, when present, supplies only OPERATION STATUS, COMMANDER INTENT, and ACTIONS. Do not use another history source, a date after $operationDate, Daily Assessment, or legacyDns data.
Preserve every source fact exactly. Do not recalculate nutrition, expenditure, calorie balance, steps, body changes, digestive data, or any other fact. Preserve null as null. Do not infer or complete missing facts.
Analyze relationships across domains instead of merely repeating or re-listing source values. Cite only the facts needed as evidence, and center each domain evaluation on what those facts support. Do not infer trends from a single value or invent events, feelings, causes, or outcomes that the FORMAL SOURCE JSON does not confirm. Treat anything unsupported by the source as not confirmed.
In human-readable analysis text, use natural Japanese descriptions rather than exposing internal field identifiers or raw boolean expressions such as trainingPerformed=false or officialSteps. Do not change their meaning, and keep all schema field names unchanged in the JSON structure and sources object.
Compare DAILY BRIEF intent with execution only when DAILY BRIEF exists. When DAILY BRIEF is absent, commanderIntentEvaluation must be null. DOMAIN EVALUATIONS body, recovery, condition, work, nutrition, hydration, activity, and training are each string or null. When a domain has no formal fact to evaluate, its evaluation must be explicit null; do not turn absence into prose such as not performed, none, no problem, good, or not assessable. In particular, when trainingPerformed is false and there is no formal Training fact to evaluate, domainEvaluations.training must be null. The false fact may still support cross-analysis against a DAILY BRIEF instruction to avoid additional training load, but it must not create a Training domain evaluation.
In human-readable analysis text only, render every kcal value as a rounded whole number with thousands separators. For example, render 2139.23kcal as 2,139kcal, 2685.6kcal as 2,686kcal, and -355.6kcal as -356kcal. Continue removing apparent floating-point artifacts from non-kcal decimal facts at a natural precision; for example, render 62.06999999999999 as 62.07g and 295.53999999999996 as 295.54g. Keep naturally integral facts such as steps, hydration mL, sleep minutes, and work minutes integral. This formatting applies only to analysis prose: do not alter, round, recalculate, estimate, or re-save any FORMAL SOURCE JSON value, and do not change or recalculate any source digest.
executionEvaluation.adjustments must contain only actionable improvements supported by formal facts and analysis. Do not add an item merely saying that something cannot be confirmed or evaluated. nextDayHandoff.watchPoints may contain only fact-supported matters worth checking in the next STATUS; it must not decide the next-day operation or create carryover.
Do not create dailySummary, overallSummary, debriefSummary, executionSummary, carryover, Commander Intent, next-day actions, or priorities. nextDayHandoff contains WATCH POINTS only.

COMPACT WRITING CONTRACT
commanderIntentEvaluation.rationale should be one sentence and must be no more than two sentences. Include only what directly supports the Commander Intent judgment. commanderIntentEvaluation.evidence must contain at most 3 short phrases or sentences. executionEvaluation.successes must contain at most 3 important successes. executionEvaluation.adjustments must contain at most 2 actionable improvements and may be []. Each crossAnalysis array must contain at most 2 items and may be []; do not fill an array merely for completeness or repeat the same fact across arrays. Each non-null domain evaluation should generally be one sentence and state the important meaning of current facts in Recent Context rather than merely restating them. Use null when there is no important supported analysis. nextDayHandoff.watchPoints must contain at most 3 items worth checking in the next STATUS or DAILY BRIEF and must not summarize the current day again.
Place a fact in the section where it carries the most meaning. Refer to it elsewhere only briefly when essential; do not repeatedly list sleep, work duration, steps, intake, or hydration across sections.
SECTION RESPONSIBILITY AND GLOBAL NON-DUPLICATION
executionEvaluation contains only execution results and actionable improvements. crossAnalysis.keyFactors contains only major factors that shaped the whole day and must not repeat an execution success. crossAnalysis.interactions requires a supported relationship between at least two domains; never reword a single-domain fact as an interaction. crossAnalysis.constraints contains only conditions that constrained execution or decisions and must not repeat a success or interaction. crossAnalysis.resources contains only clear resources that supported the day's operation; use [] when it would merely repeat Nutrition or Hydration facts. domainEvaluations contains only domain-specific meaning and must not expand execution successes or cross-domain interactions. nextDayHandoff.watchPoints contains only matters worth checking in the next STATUS or DAILY BRIEF and must not repeat successes or cross-analysis.
Do not repeat the same fact or a synonymous statement across multiple sections. Reuse a fact only when the destination section adds distinct section-specific analytical value. Prefer responsibility separation, then non-duplication, then concision, then information volume. Empty arrays and null domain evaluations are valid and preferred over duplicated filler.
Do not evaluate or penalize unobservable behavior, including whether a break was actually used for rest, whether sleep began immediately after work, or what happened after returning home. Do not include those matters in rationale, evidence, adjustments, or watchPoints. Use notAssessable only when the core Commander Intent itself cannot be judged from the formal sources; do not lower an outcome because only a supporting detail is unobservable.
In Japanese prose, use 睡眠 and 睡眠スコア. Never write Sleep Score or SLEEP SCORE. Describe officialSteps naturally as a step count such as 6,952歩 or 活動量は6,952歩; never expose 正式歩数, Official Steps, or officialSteps in analysis prose. Continue to ignore measured or raw steps and never explain their difference.
Use concise natural Japanese. Do not use internal expressions such as Formal Fact, Operational Impact, sourceType=records, 補給資源として記録された, or 負のエネルギー収支が記録された. Prefer direct wording such as 推定収支は-356kcalだった。

${_recentContextAnalysisContract(currentFact: 'the target-day finalized DAILY AGGREGATE')}
${_humanReadableAnalysisContract(includeNumericFormatting: false)}

RESPONSE CONTRACT
Return exactly one fenced Plain Text code block whose opening fence is ```text and whose closing fence is ```. Return nothing outside that code block: no explanation, heading, greeting, note, preface, afterword, or additional code block. Inside the code block, return exactly one JSON object and no prose, comments, headings, or multiple JSON values. The user will use ChatGPT's code-block copy action; the copied content must start with { and end with } without the fences.
Use only ASCII half-width double quotation marks (U+0022) for JSON syntax. Never use smart or curly quotes such as “ ” or ‘ ’. Return the exact COMPLETE ANALYSIS SHAPE only. Do not return an envelope, operationDate, recordVersion, sources, source digests, revision, timestamps, exchange identity, confirmationDigest, or packageDigest. Operation Reboot retains and binds all formal identity and source information. Do not add unknown fields, remove fields, rename fields, omit required fields, or add schema-external sections. Nullable fields must be explicit null. Required array fields must be present and use [] when empty. Every string and array item must be non-empty after trimming. Use only these outcome values: achieved, partiallyAchieved, notAchieved, notAssessable.
Before returning, internally verify that the JSON is syntactically complete and structurally matches the exact schema: the root contains exactly one object; object and array nesting is balanced; every opening brace, bracket, and ASCII quote has its matching closing character; there is no extra or missing closing brace; there is no trailing comma; every required field exists; and no unknown field exists. Do not output this verification process or a checklist. The final response must contain only the verified JSON object inside the single Plain Text code block.
Invalid JSON cannot be imported. Do not rely on the app to repair smart quotes, braces, brackets, commas, keys, fields, dates, digests, nulls, or values.

FORMAL SOURCE JSON
${const JsonEncoder.withIndent('  ').convert(source)}

COMPLETE ANALYSIS SHAPE
${const JsonEncoder.withIndent('  ').convert(analysis)}
'''
        .trim();
  }

  String _buildMorningBriefInstruction(
    String operationDate,
    String sourceRecordId,
    String sourceDigest,
    Map<String, Object?> recentContext,
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

CURRENT FACT AND RECENT CONTEXT CONTRACT
This final contract supersedes any earlier wording that limits analysis to STATUS alone. The target-date STATUS is the CURRENT FACT and always has priority. RECENT CONTEXT is supporting context derived only from records-source Daily Aggregates for D-7 through D-1. Do not use target-day unfinalized data, future data, legacyDns, Body History, Nutrition History, or STATUS History as Recent Context.
${_recentContextAnalysisContract(currentFact: 'the target-day STATUS')}
${_humanReadableAnalysisContract()}

RECENT CONTEXT JSON
${const JsonEncoder.withIndent('  ').convert(recentContext)}
'''
        .trim();
  }

  String _recentContextAnalysisContract({required String currentFact}) =>
      '''
RECENT CONTEXT ANALYSIS CONTRACT
Prioritize $currentFact. Use RECENT CONTEXT only to interpret the current fact in its recent direction and range. Each metric contains average, start, end, and validCount over non-null values. Numeric zero is a valid fact; null is missing and must never become zero. Do not invent UP, DOWN, or STABLE labels. Do not mechanically dismiss a current value because it is a single-day value. Describe a direction only when the supplied context supports it, avoid strong trend claims when validCount is small, and never infer an unrecorded cause.
For plantarFasciitisLevel, a higher level means a stronger symptom and a lower level means a lighter symptom. For activity, use only officialSteps. Never mention, compare, or infer measured steps, raw steps, device steps, or the reason for a difference. Expenditure and calorie balance values are stored facts; never recalculate them from other metrics.
''';

  String _humanReadableAnalysisContract({
    bool includeNumericFormatting = true,
  }) =>
      '''
HUMAN-READABLE ANALYSIS CONTRACT
${includeNumericFormatting ? 'In Japanese analysis prose only, add thousands separators to numbers of four or more digits: 2330 becomes 2,330; 3250 becomes 3,250; 6952 becomes 6,952; and 2685.6 becomes 2,685.6. Continue removing apparent floating-point artifacts at a natural precision. Do not alter any source JSON value, stored value, unit, or digest.' : ''}
Render duration minutes as H:MM in prose, with two minute digits: 229 minutes is 3:49, 360 is 6:00, 60 is 1:00, and 522 is 8:42. Keep source and derived duration values in minutes.
Write natural Japanese and do not expose internal terms such as trainingPerformed=false, officialSteps, Formal Fact, sourceType=records, or Operational Impact. Refer to the user-facing products as DAILY BRIEF and STATUS, never MORNING BRIEF or MORNING ROUTINE in analysis prose. Do not list irrelevant unknowns or statements that something cannot be confirmed. Use notAssessable, null, or a concise rationale only when missing information directly prevents a required evaluation. Adjustments and WATCH POINTS must be supported by current facts or Recent Context; do not add speculative items.
''';

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
