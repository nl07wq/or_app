import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_history.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/services/training_exercise_identity.dart';
import 'package:or_app/features/training_analysis/services/training_analysis_service.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  const targetDate = '2026-08-21';
  final now = DateTime.utc(2026, 8, 21, 12);

  test(
    'builds formal facts with the latest five comparable sessions',
    () async {
      final fixture = await _fixture(now);
      final preparation = await fixture.service.prepare(fixture.targetId);

      expect(preparation.target.id, fixture.targetId);
      expect(preparation.prompt, contains('"operationDate": "$targetDate"'));
      expect(
        preparation.prompt,
        contains('"targetRecordId": "${fixture.targetId}"'),
      );
      for (final date in const [
        '2026-08-20',
        '2026-08-19',
        '2026-08-18',
        '2026-08-17',
        '2026-08-16',
      ]) {
        expect(preparation.prompt, contains('"operationDate": "$date"'));
      }
      expect(
        preparation.prompt,
        isNot(contains('"operationDate": "2026-08-15"')),
      );
      expect(preparation.prompt, contains('"changeFromCurrent"'));
      expect(preparation.prompt, contains('"volumeKg"'));
    },
  );

  test(
    'validates target identity and keeps the Formal Training Record unchanged',
    () async {
      final fixture = await _fixture(now);
      final preparation = await fixture.service.prepare(fixture.targetId);
      final before = (await fixture.container.training.findRecordById(
        fixture.targetId,
      ))!;
      final response = _response(
        fixture.container,
        targetId: fixture.targetId,
        sourceDigest: preparation.sourceDigest,
        exchangeId: 'training-analysis-response:1',
        summary: '初回分析です。',
        now: now,
      );

      final preview = await fixture.service.preview(
        fixture.targetId,
        fixture.container.reportSyncCodec.encode(response),
      );
      expect(preview.disposition, ReportSyncHistoryResult.success);
      await fixture.service.apply(preview);
      final after = (await fixture.container.training.findRecordById(
        fixture.targetId,
      ))!;
      expect(after.v2Data!.toJson(), before.v2Data!.toJson());
      expect(after.updatedAt, before.updatedAt);
    },
  );

  test(
    'imports Rev 1 and Rev 2, preserves Rev 1, and detects noChanges',
    () async {
      final fixture = await _fixture(now);
      final preparation = await fixture.service.prepare(fixture.targetId);

      Future<TrainingAnalysisImportResult> import(
        String exchangeId,
        String summary,
      ) async {
        final response = _response(
          fixture.container,
          targetId: fixture.targetId,
          sourceDigest: preparation.sourceDigest,
          exchangeId: exchangeId,
          summary: summary,
          now: now,
        );
        final preview = await fixture.service.preview(
          fixture.targetId,
          fixture.container.reportSyncCodec.encode(response),
        );
        return fixture.service.apply(preview);
      }

      final first = await import('training-analysis-response:1', '初回分析です。');
      expect(first.report.revision, 1);
      expect(first.report.previousRevisions, isEmpty);

      final second = await import('training-analysis-response:2', '更新分析です。');
      expect(second.report.revision, 2);
      expect(second.report.previousRevisions, hasLength(1));
      expect(
        second.report.previousRevisions.single.analysis.sessionSummary,
        '初回分析です。',
      );
      expect(second.report.analysis.sessionSummary, '更新分析です。');

      final noChange = await import('training-analysis-response:3', '更新分析です。');
      expect(noChange.result, ReportSyncHistoryResult.noChange);
      expect(noChange.report.revision, 2);
      expect(noChange.report.previousRevisions, hasLength(1));
    },
  );
}

Future<_Fixture> _fixture(DateTime now) async {
  final database = FakeIndexedDbDatabase();
  final container = AppRepositoryContainer.indexedDb(database);
  await container.operationState.createInitial(
    OperationLocalDate.parse('2026-08-21'),
  );
  for (var day = 15; day <= 20; day++) {
    await container.training.saveNewV2(
      _session('2026-08-$day', day.toDouble()),
    );
  }
  final target = await container.training.saveNewV2(_session('2026-08-21', 70));
  return _Fixture(
    container: container,
    service: TrainingAnalysisService(container: container, clock: () => now),
    targetId: target.id,
  );
}

TrainingSessionV2 _session(String date, double weight) => TrainingSessionV2(
  date: '${date}T10:00:00+09:00',
  startTime: '${date}T10:00:00+09:00',
  endTime: '${date}T11:00:00+09:00',
  sessionName: 'Strength',
  memo: 'Formal memo',
  exercises: [
    TrainingExerciseV2(
      exerciseName: 'Bench Press',
      order: 1,
      sets: [
        TrainingSetV2(
          setNo: 1,
          setType: TrainingSetType.main,
          weightKg: weight,
          reps: 8,
        ),
      ],
    ),
  ],
);

ReportSyncEnvelope _response(
  AppRepositoryContainer container, {
  required String targetId,
  required String sourceDigest,
  required String exchangeId,
  required String summary,
  required DateTime now,
}) {
  final identity = TrainingExerciseIdentity.v2(
    _session('2026-08-21', 70).exercises.single,
  );
  return container.reportSyncCodec.create(
    direction: ReportSyncDirection.response,
    schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
    exchangeType: ReportSyncExchangeType.trainingAnalysis,
    exchangeId: exchangeId,
    operationDate: '2026-08-21',
    createdAt: now,
    payload: {
      'operationDate': '2026-08-21',
      'targetRecordId': targetId,
      'sourceDigest': sourceDigest,
      'analysis': {
        'sessionSummary': summary,
        'performanceAnalysis': 'パフォーマンス分析です。',
        'previousComparison': '前回比較です。',
        'progressAnalysis': '進捗分析です。',
        'recoveryFrequencyComment': '回復頻度の所見です。',
        'nextSessionProposal': '次回提案です。',
        'riskAttentionNotes': '注意事項です。',
        'exerciseAnalyses': [
          {
            'exerciseIdentity':
                '${identity.exerciseKey}|${identity.equipmentKey}',
            'exerciseName': 'Bench Press',
            'assessment': '評価です。',
            'previousComparison': '種目比較です。',
            'progress': '種目進捗です。',
            'nextProposal': '種目提案です。',
          },
        ],
      },
    },
  );
}

class _Fixture {
  const _Fixture({
    required this.container,
    required this.service,
    required this.targetId,
  });

  final AppRepositoryContainer container;
  final TrainingAnalysisService service;
  final String targetId;
}
