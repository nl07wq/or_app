import 'report_sync_record_utils.dart';

/// Immutable provenance emitted with a generated DAILY BRIEF response.
///
/// This is deliberately separate from Japanese display prose. It preserves the
/// source snapshot and the rule-level evaluation that produced the stored
/// operation status, without re-evaluating mutable STATUS records later.
class MorningBriefDecisionTrace {
  const MorningBriefDecisionTrace({
    required this.traceSchemaVersion,
    required this.modelVersion,
    required this.ruleSetVersion,
    required this.sourceSnapshot,
    required this.rules,
    required this.interactions,
    required this.finalDecision,
  });

  static const fields = {
    'traceSchemaVersion',
    'modelVersion',
    'ruleSetVersion',
    'sourceSnapshot',
    'rules',
    'interactions',
    'finalDecision',
  };

  final String traceSchemaVersion;
  final String modelVersion;
  final String ruleSetVersion;
  final Map<String, Object?> sourceSnapshot;
  final List<MorningBriefRuleEvaluation> rules;
  final List<MorningBriefRuleEvaluation> interactions;
  final MorningBriefFinalDecisionTrace finalDecision;

  Map<String, Object?> toJson() => {
    'traceSchemaVersion': traceSchemaVersion,
    'modelVersion': modelVersion,
    'ruleSetVersion': ruleSetVersion,
    'sourceSnapshot': sourceSnapshot,
    'rules': [for (final value in rules) value.toJson()],
    'interactions': [for (final value in interactions) value.toJson()],
    'finalDecision': finalDecision.toJson(),
  };

  factory MorningBriefDecisionTrace.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final source = json['sourceSnapshot'];
    final rules = json['rules'];
    final interactions = json['interactions'];
    final finalDecision = json['finalDecision'];
    if (source is! Map ||
        rules is! List ||
        interactions is! List ||
        finalDecision is! Map ||
        rules.any((value) => value is! Map) ||
        interactions.any((value) => value is! Map)) {
      throw const FormatException('DAILY BRIEF decision trace is invalid.');
    }
    return MorningBriefDecisionTrace(
      traceSchemaVersion: ReportSyncRecordUtils.string(
        json,
        'traceSchemaVersion',
      ),
      modelVersion: ReportSyncRecordUtils.string(json, 'modelVersion'),
      ruleSetVersion: ReportSyncRecordUtils.string(json, 'ruleSetVersion'),
      sourceSnapshot: Map.unmodifiable(Map<String, Object?>.from(source)),
      rules: List.unmodifiable([
        for (final value in rules)
          MorningBriefRuleEvaluation.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
      ]),
      interactions: List.unmodifiable([
        for (final value in interactions)
          MorningBriefRuleEvaluation.fromJson(
            Map<String, Object?>.from(value as Map),
          ),
      ]),
      finalDecision: MorningBriefFinalDecisionTrace.fromJson(
        Map<String, Object?>.from(finalDecision),
      ),
    );
  }

  /// A deterministic, display-text-independent representation for audits.
  Map<String, Object?> toAuditRepresentation() => toJson();
}

class MorningBriefRuleEvaluation {
  const MorningBriefRuleEvaluation({
    required this.ruleId,
    required this.ruleVersion,
    required this.domain,
    required this.inputFacts,
    required this.result,
    required this.effect,
    required this.reasonCode,
  });

  static const fields = {
    'ruleId',
    'ruleVersion',
    'domain',
    'inputFacts',
    'result',
    'effect',
    'reasonCode',
  };

  final String ruleId;
  final String ruleVersion;
  final String domain;
  final Map<String, Object?> inputFacts;
  final String result;
  final String effect;
  final String reasonCode;

  Map<String, Object?> toJson() => {
    'ruleId': ruleId,
    'ruleVersion': ruleVersion,
    'domain': domain,
    'inputFacts': inputFacts,
    'result': result,
    'effect': effect,
    'reasonCode': reasonCode,
  };

  factory MorningBriefRuleEvaluation.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final inputs = json['inputFacts'];
    if (inputs is! Map) {
      throw const FormatException('DAILY BRIEF rule inputs are invalid.');
    }
    return MorningBriefRuleEvaluation(
      ruleId: ReportSyncRecordUtils.string(json, 'ruleId'),
      ruleVersion: ReportSyncRecordUtils.string(json, 'ruleVersion'),
      domain: ReportSyncRecordUtils.string(json, 'domain'),
      inputFacts: Map.unmodifiable(Map<String, Object?>.from(inputs)),
      result: ReportSyncRecordUtils.string(json, 'result'),
      effect: ReportSyncRecordUtils.string(json, 'effect'),
      reasonCode: ReportSyncRecordUtils.string(json, 'reasonCode'),
    );
  }
}

class MorningBriefFinalDecisionTrace {
  const MorningBriefFinalDecisionTrace({
    required this.candidateStatuses,
    required this.modifiers,
    required this.guardrails,
    required this.operationStatus,
    required this.reasonCodes,
  });

  static const fields = {
    'candidateStatuses',
    'modifiers',
    'guardrails',
    'operationStatus',
    'reasonCodes',
  };

  final Map<String, Object?> candidateStatuses;
  final List<String> modifiers;
  final List<String> guardrails;
  final String operationStatus;
  final List<String> reasonCodes;

  Map<String, Object?> toJson() => {
    'candidateStatuses': candidateStatuses,
    'modifiers': modifiers,
    'guardrails': guardrails,
    'operationStatus': operationStatus,
    'reasonCodes': reasonCodes,
  };

  factory MorningBriefFinalDecisionTrace.fromJson(Map<String, Object?> json) {
    ReportSyncRecordUtils.exactFields(json, fields);
    final candidates = json['candidateStatuses'];
    final modifiers = json['modifiers'];
    final guardrails = json['guardrails'];
    final reasons = json['reasonCodes'];
    if (candidates is! Map ||
        modifiers is! List ||
        guardrails is! List ||
        reasons is! List ||
        modifiers.any((value) => value is! String) ||
        guardrails.any((value) => value is! String) ||
        reasons.any((value) => value is! String)) {
      throw const FormatException('DAILY BRIEF final trace is invalid.');
    }
    return MorningBriefFinalDecisionTrace(
      candidateStatuses: Map.unmodifiable(
        Map<String, Object?>.from(candidates),
      ),
      modifiers: List.unmodifiable(modifiers.cast<String>()),
      guardrails: List.unmodifiable(guardrails.cast<String>()),
      operationStatus: ReportSyncRecordUtils.string(json, 'operationStatus'),
      reasonCodes: List.unmodifiable(reasons.cast<String>()),
    );
  }
}
