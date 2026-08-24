import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/state/app_initialization_state.dart';
import 'package:or_app/core/widgets/operation_button.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/training_page.dart';
import 'package:or_app/features/training_analysis/models/training_analysis_report.dart';
import 'package:or_app/features/training_analysis/pages/training_analysis_page.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  setUp(AppRepositoryRegistry.resetForTesting);
  tearDown(AppRepositoryRegistry.resetForTesting);

  testWidgets('Training top uses the centered primary Analysis action', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TrainingPage()));

    final label = find.text('TRAINING ANALYSIS REPORT');
    final button = find.ancestor(
      of: label,
      matching: find.byType(OperationButton),
    );
    expect(find.text('ANALYSIS REPORT'), findsOneWidget);
    expect(find.text('PLAN'), findsOneWidget);
    expect(find.text('TRAINING PLAN'), findsOneWidget);
    expect(button, findsOneWidget);
    expect(
      find.descendant(
        of: button,
        matching: find.byIcon(Icons.analytics_outlined),
      ),
      findsOneWidget,
    );
    final row = tester.widget<Row>(
      find.descendant(of: button, matching: find.byType(Row)),
    );
    expect(row.mainAxisAlignment, MainAxisAlignment.center);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 390, 900]) {
    testWidgets('Analysis report has three readable layers without overflow at '
        '${width.toInt()}px', (tester) async {
      final fixture = await _pumpReport(tester, width: width);

      expect(find.text('TRAINING ANALYSIS REPORT'), findsWidgets);
      expect(find.text('REV 2  LATEST'), findsOneWidget);
      expect(find.text('SUMMARY'), findsOneWidget);
      expect(find.text('SESSION SUMMARY'), findsOneWidget);
      expect(find.text('PERFORMANCE'), findsOneWidget);
      expect(find.text('PREVIOUS SESSION'), findsOneWidget);
      expect(find.text('PROGRESS'), findsOneWidget);
      expect(find.text('EXERCISE BREAKDOWN'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('training-analysis-exercise-bench-press')),
        findsOneWidget,
      );
      expect(find.text('CURRENT / ASSESSMENT'), findsOneWidget);
      expect(find.text('VS PREVIOUS'), findsOneWidget);
      expect(find.text('ANALYSIS / PROGRESS'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('NEXT ACTIONS'), findsOneWidget);
      expect(find.text('NEXT SESSION'), findsOneWidget);
      expect(find.text('RECOVERY / FREQUENCY'), findsOneWidget);
      expect(find.text('RISK / ATTENTION'), findsOneWidget);
      expect(find.text('CREATE ANALYSIS'), findsOneWidget);
      expect(find.text('CREATE NEXT PLAN'), findsOneWidget);
      expect(find.text('COPY REVISION PROMPT'), findsOneWidget);
      expect(find.text(_sessionSummary), findsOneWidget);
      expect(find.text(_performance), findsOneWidget);
      expect(find.text(_previous), findsOneWidget);
      expect(find.text(_progress), findsOneWidget);
      expect(find.text(_assessment), findsOneWidget);
      expect(find.text(_exercisePrevious), findsOneWidget);
      expect(find.text(_exerciseProgress), findsOneWidget);
      expect(find.text(_exerciseNext), findsOneWidget);
      expect(find.text(_nextSession), findsOneWidget);
      expect(find.text(_recovery), findsOneWidget);
      expect(find.text(_risk), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('PREVIOUS REVISIONS'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PREVIOUS REVISIONS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(fixture.report.analysis.toJson(), fixture.analysisBefore);
    });
  }
}

Future<_Fixture> _pumpReport(
  WidgetTester tester, {
  required double width,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final database = FakeIndexedDbDatabase();
  final container = AppRepositoryContainer.indexedDb(database);
  final record = await container.training.saveNewV2(
    TrainingSessionV2(
      date: '2026-08-24T10:00:00+09:00',
      sessionName: 'Strength',
      exercises: [
        TrainingExerciseV2(
          exerciseName: 'Bench Press',
          order: 1,
          sets: [
            TrainingSetV2(
              setNo: 1,
              setType: TrainingSetType.main,
              weightKg: 80,
              reps: 8,
            ),
          ],
        ),
      ],
    ),
  );
  final initial = TrainingAnalysisReport.initial(
    targetRecordId: record.id,
    operationDate: record.localDate,
    sourceDigest: _digest('a'),
    responseDigest: _digest('b'),
    exchangeId: 'analysis-response-1',
    timestamp: DateTime.utc(2026, 8, 24, 12),
    analysis: _analysis('previous'),
  );
  final report = initial.revise(
    sourceDigest: _digest('a'),
    responseDigest: _digest('c'),
    exchangeId: 'analysis-response-2',
    timestamp: DateTime.utc(2026, 8, 24, 13),
    analysis: _analysis('latest'),
  );
  database.seed(
    IndexedDbStoreNames.trainingAnalysisReportRecords,
    report.targetRecordId,
    report.toRecord(),
  );

  final initialization = AppInitializationController()..markReady();
  AppRepositoryRegistry.beginStartup(controller: initialization);
  AppRepositoryRegistry.install(container);

  await tester.pumpWidget(
    MaterialApp(home: TrainingAnalysisPage(targetRecordId: record.id)),
  );
  await tester.pumpAndSettle();
  return _Fixture(report: report, analysisBefore: report.analysis.toJson());
}

TrainingAnalysis _analysis(String revision) => TrainingAnalysis(
  sessionSummary: revision == 'latest' ? _sessionSummary : '以前のSummaryです。',
  performanceAnalysis: _performance,
  previousComparison: _previous,
  progressAnalysis: _progress,
  recoveryFrequencyComment: _recovery,
  nextSessionProposal: _nextSession,
  riskAttentionNotes: _risk,
  exerciseAnalyses: const [
    TrainingExerciseAnalysis(
      exerciseIdentity: 'bench-press',
      exerciseName: 'Bench Press',
      assessment: _assessment,
      previousComparison: _exercisePrevious,
      progress: _exerciseProgress,
      nextProposal: _exerciseNext,
    ),
  ],
);

String _digest(String value) => value * 64;

const _sessionSummary = '今回のTraining全体を示すSession Summaryです。';
const _performance = '既存Performance本文を変更せず表示します。';
const _previous = '既存Previous Comparison本文をそのまま表示します。';
const _progress = '既存Progress本文をそのまま表示します。';
const _assessment = '種目のAssessment本文です。';
const _exercisePrevious = '種目のPrevious本文です。';
const _exerciseProgress = '種目のProgress本文です。';
const _exerciseNext = '種目のNext本文です。';
const _nextSession = '次回Session提案本文です。';
const _recovery = 'RecoveryとFrequencyの本文です。';
const _risk = 'RiskとAttentionの本文です。';

class _Fixture {
  const _Fixture({required this.report, required this.analysisBefore});

  final TrainingAnalysisReport report;
  final Map<String, Object?> analysisBefore;
}
