import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/report_sync/models/morning_brief_decision_trace.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';

void main() {
  test(
    'trace is immutable, serializable, and independent of display prose',
    () {
      final trace = _trace();
      final record = _record(trace);
      final restored = MorningBriefRecord.fromRecord(record.toRecord());

      expect(restored.decisionTrace?.sourceSnapshot['footPainLevel'], 4);
      expect(restored.decisionTrace?.rules.single.effect, 'ESCALATE_YELLOW');
      expect(
        restored.decisionTrace?.toAuditRepresentation(),
        trace.toAuditRepresentation(),
      );
    },
  );

  test('old records explicitly have unavailable traces', () {
    final record = _record(null);
    expect(
      MorningBriefRecord.fromRecord(record.toRecord()).decisionTrace,
      isNull,
    );
  });

  test('trace final status must match the stored production status', () {
    final invalid = MorningBriefDecisionTrace.fromJson({
      ..._trace().toJson(),
      'finalDecision': {
        ..._trace().finalDecision.toJson(),
        'operationStatus': 'red',
      },
    });
    expect(() => _record(invalid), throwsFormatException);
  });
}

MorningBriefRecord _record(MorningBriefDecisionTrace? trace) =>
    MorningBriefRecord.v2(
      localDate: '2026-09-25',
      sourceType: 'status',
      sourceOperationDate: '2026-09-25',
      sourceRecordId: 'status:2026-09-25',
      sourceDigest: 'a' * 64,
      evaluationVersion: 'plantar-risk-v2',
      decisionTrace: trace,
      responseDigest: 'b' * 64,
      exchangeId: 'exchange-1',
      generatedAt: DateTime.utc(2026, 9, 25),
      importedAt: DateTime.utc(2026, 9, 25),
      situationAnalysisV2: const MorningBriefSituationAnalysis(
        body: 'body',
        recovery: 'recovery',
        condition: 'condition',
        work: 'work',
        carryover: 'carryover',
        overall: 'overall',
      ),
      operatingPolicy: 'policy',
      strategicResourceDecisionV2: const MorningBriefStrategicResourceDecision(
        decision: 'decision',
        targetResource: null,
        rationale: 'rationale',
        execution: null,
      ),
      operationStatus: MorningBriefOperationStatus.yellow,
      commanderIntent: 'intent',
      actions: const [],
      createdAt: DateTime.utc(2026, 9, 25),
      updatedAt: DateTime.utc(2026, 9, 25),
    );

MorningBriefDecisionTrace _trace() => MorningBriefDecisionTrace(
  traceSchemaVersion: 'decision-trace-v1',
  modelVersion: 'plantar-risk-v2',
  ruleSetVersion: 'plantar-risk-v2',
  sourceSnapshot: const {
    'footPainLevel': 4,
    'workHours': 8,
    'sleepDurationMinutes': null,
  },
  rules: const [
    MorningBriefRuleEvaluation(
      ruleId: 'plantar-watch',
      ruleVersion: 'v2',
      domain: 'condition',
      inputFacts: {'footPainLevel': 4},
      result: 'watch',
      effect: 'ESCALATE_YELLOW',
      reasonCode: 'PLANTAR_WATCH',
    ),
  ],
  interactions: const [
    MorningBriefRuleEvaluation(
      ruleId: 'plantar-work',
      ruleVersion: 'v2',
      domain: 'condition-work',
      inputFacts: {'footPainLevel': 4, 'workHours': 8},
      result: 'neutral',
      effect: 'NEUTRAL',
      reasonCode: 'NORMAL_WORK_NEUTRAL',
    ),
  ],
  finalDecision: const MorningBriefFinalDecisionTrace(
    candidateStatuses: {'condition': 'yellow'},
    modifiers: [],
    guardrails: [],
    operationStatus: 'yellow',
    reasonCodes: ['PLANTAR_WATCH'],
  ),
);
