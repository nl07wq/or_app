import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/services/daily_brief_plantar_risk_review_service.dart';

void main() {
  const service = DailyBriefPlantarRiskReviewService();

  test('counts only version-provenanced DAILY BRIEFs by operation date', () {
    final summary = service.summarize([
      _brief('2026-09-01', MorningBriefOperationStatus.green),
      _brief('2026-09-02', MorningBriefOperationStatus.yellow),
      _brief('2026-09-02', MorningBriefOperationStatus.red, updatedAt: 2),
      _brief('2026-09-03', MorningBriefOperationStatus.green, version: null),
      _brief(
        '2026-09-04',
        MorningBriefOperationStatus.red,
        version: 'plantar-risk-v1',
      ),
    ]);

    expect(summary.observationCount, 2);
    expect(summary.greenCount, 1);
    expect(summary.yellowCount, 0);
    expect(summary.redCount, 1);
    expect(summary.state, DailyBriefPlantarRiskReviewState.collecting);
  });

  test('uses collecting, review building, and review ready milestones', () {
    expect(
      service.summarize(const []).state,
      DailyBriefPlantarRiskReviewState.collecting,
    );
    expect(
      service.summarize(_briefs(4)).state,
      DailyBriefPlantarRiskReviewState.collecting,
    );
    expect(
      service.summarize(_briefs(5)).state,
      DailyBriefPlantarRiskReviewState.reviewBuilding,
    );
    final ready = service.summarize(_briefs(10));
    expect(ready.state, DailyBriefPlantarRiskReviewState.reviewReady);
    expect(ready.observationCount, 10);
    expect(ready.greenCount + ready.yellowCount + ready.redCount, 10);
  });

  test('reports the canonical GREEN, YELLOW, and RED distribution', () {
    final records = [
      for (var index = 0; index < 5; index++)
        _brief('2026-08-${(index + 1).toString().padLeft(2, '0')}', MorningBriefOperationStatus.green),
      for (var index = 0; index < 4; index++)
        _brief('2026-08-${(index + 6).toString().padLeft(2, '0')}', MorningBriefOperationStatus.yellow),
      _brief('2026-08-10', MorningBriefOperationStatus.red),
    ];

    final summary = service.summarize(records);
    expect(summary.observationCount, 10);
    expect(summary.greenCount, 5);
    expect(summary.yellowCount, 4);
    expect(summary.redCount, 1);
  });

  test('keeps evaluation provenance through record serialization', () {
    final record = _brief(
      '2026-09-01',
      MorningBriefOperationStatus.green,
    ).asInitialRevision();
    final restored = MorningBriefRecord.fromRecord(record.toRecord());

    expect(restored.evaluationVersion, 'plantar-risk-v2');
    expect(restored.recordVersion, MorningBriefRecord.currentRecordVersion);
  });
}

List<MorningBriefRecord> _briefs(int count) => [
  for (var index = 0; index < count; index++)
    _brief('2026-09-${(index + 1).toString().padLeft(2, '0')}', switch (index %
        3) {
      0 => MorningBriefOperationStatus.green,
      1 => MorningBriefOperationStatus.yellow,
      _ => MorningBriefOperationStatus.red,
    }),
];

MorningBriefRecord _brief(
  String localDate,
  MorningBriefOperationStatus status, {
  String? version = 'plantar-risk-v2',
  int updatedAt = 1,
}) => MorningBriefRecord.v2(
  localDate: localDate,
  sourceType: 'status',
  sourceOperationDate: localDate,
  sourceRecordId: 'status:$localDate',
  sourceDigest:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  evaluationVersion: version,
  responseDigest:
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  exchangeId: 'exchange:$localDate:$updatedAt',
  generatedAt: DateTime.utc(2026, 9, 1),
  importedAt: DateTime.utc(2026, 9, 1),
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
  operationStatus: status,
  commanderIntent: 'intent',
  actions: const [],
  createdAt: DateTime.utc(2026, 9, 1),
  updatedAt: DateTime.utc(2026, 9, updatedAt),
);
