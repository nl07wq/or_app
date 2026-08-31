import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/data/indexed_db/indexed_db_store_names.dart';
import 'package:or_app/features/operation_date/models/operation_local_date.dart';
import 'package:or_app/features/report_sync/models/report_sync_envelope.dart';
import 'package:or_app/features/report_sync/models/report_sync_issue.dart';
import 'package:or_app/features/repositories/app_repository_container.dart';
import 'package:or_app/features/training/models/active_training_draft.dart';
import 'package:or_app/features/training/models/training_plan_proposal.dart';
import 'package:or_app/features/training/models/training_v2_form_controller.dart';
import 'package:or_app/features/training/repository/indexed_db_active_training_draft_repository.dart';
import 'package:or_app/features/training/services/training_exercise_identity.dart';
import 'package:or_app/features/training/services/training_plan_service.dart';
import 'package:or_app/features/training/services/training_v2_form_mapper.dart';
import 'package:or_app/features/training/training_plan_import_page.dart';
import 'package:or_app/features/training_analysis/models/training_analysis_report.dart';

import '../../repositories/indexed_db/fake_indexed_db_database.dart';

void main() {
  testWidgets('IMPORT PLAN provides paste clear and validate actions', (
    tester,
  ) async {
    final fixture = await _fixture();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPlanImportPage(
          sourceRecordId: fixture.targetId,
          service: fixture.service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PASTE'), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_outlined), findsOneWidget);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
    await tester.enterText(find.byType(TextField), '{"test":true}');

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.text('CLEAR'));
    await tester.pump();
    expect(
      (tester.widget<TextField>(find.byType(TextField))).controller?.text,
      isEmpty,
    );
    expect(find.text('VALIDATE'), findsOneWidget);
  });
  test('prompt owns facts, five comparables, and latest analysis', () async {
    final fixture = await _fixture();
    final preparation = await fixture.service.prepare(
      targetRecordId: fixture.targetId,
    );

    expect(preparation.prompt, contains('"exchangeType": "trainingPlan"'));
    expect(preparation.prompt, contains('"sessionSummary": "Latest analysis"'));
    expect(preparation.prompt, contains('"planType": "training"'));
    expect(preparation.prompt, contains('"planType": "rest"'));
    for (final day in const [23, 22, 21, 20, 19]) {
      expect(preparation.prompt, contains('2026-08-$day'));
    }
    expect(preparation.prompt, isNot(contains('2026-08-18')));
    expect(preparation.prompt, contains('"weightTrendKg"'));
    expect(preparation.prompt, contains('"volumeTrendKg"'));
  });

  test('validates ranges and applies a version 3 plan-only draft', () async {
    final fixture = await _fixture();
    final preparation = await fixture.service.prepare(
      targetRecordId: fixture.targetId,
    );
    final before = await fixture.container.training.findAllRecords();
    final response = _response(
      fixture,
      sourceDigest: preparation.sourceDigest,
      identity: fixture.identity,
    );

    final preview = await fixture.service.preview(
      fixture.container.reportSyncCodec.encode(response),
    );
    expect(preview.plan.exercises.single.sets.first.targetMinReps, 8);
    expect(preview.plan.exercises.single.sets.first.targetMaxReps, 8);
    expect(preview.plan.exercises.single.sets.last.targetMinReps, 8);
    expect(preview.plan.exercises.single.sets.last.targetMaxReps, 10);

    final saved = await fixture.service.apply(preview);
    expect(saved.version, 3);
    expect(saved.startTime, isNull);
    expect(saved.endTime, isNull);
    expect(
      await fixture.container.training.findAllRecords(),
      hasLength(before.length),
    );

    final form = TrainingV2FormController.newSession(localDate: '2026-08-25');
    addTearDown(form.dispose);
    form.restoreDraftTimes(startTime: saved.startTime, endTime: saved.endTime);
    form.restoreDraftState(saved.entryState!);
    expect(form.hasPlan, isTrue);
    expect(form.startTime, isNull);
    expect(form.exercises.single.sets.last.plannedWeightKg, 70);
    expect(form.exercises.single.sets.last.targetMinReps, 8);
    expect(form.exercises.single.sets.last.targetMaxReps, 10);
    expect(form.exercises.single.sets.first.weight.text, '20');
    expect(form.exercises.single.sets.first.reps.text, '8');
    expect(form.exercises.single.sets.last.weight.text, '70');
    expect(form.exercises.single.sets.last.reps.text, '8');
    expect(form.planSourceRecordId, fixture.targetId);
    expect(form.planSourceOperationDate, '2026-08-24');

    form.exercises.single.sets.first.weight.text = '20';
    form.exercises.single.sets.first.reps.text = '8';
    form.exercises.single.sets.last.weight.text = '67.5';
    form.exercises.single.sets.last.reps.text = '9';
    final formal = TrainingV2FormMapper.toDomain(form);
    expect(formal.exercises.single.sets.last.weightKg, 67.5);
    expect(formal.exercises.single.sets.last.reps, 9);
    expect(formal.toJson().toString(), isNot(contains('plannedWeight')));
    expect(formal.toJson().toString(), isNot(contains('targetMinReps')));

    form.startTraining(DateTime(2026, 8, 25, 10));
    expect(form.startTime, isNotNull);
  });

  test('AUTO skips consecutive cardio-only records', () async {
    final fixture = await _fixture(latestCardioDays: const [25, 26]);

    final preparation = await fixture.service.prepare();

    expect(preparation.reference?.recordId, fixture.targetId);
    expect(preparation.reference?.operationDate, '2026-08-24');
    expect(preparation.referenceCandidates, hasLength(7));
    expect(preparation.prompt, contains('"latestTrainingRecord"'));
    expect(preparation.prompt, contains('"latestStrengthReference"'));
    expect(preparation.prompt, contains('2026-08-26'));
    expect(preparation.prompt, contains('2026-08-24'));
  });

  test('manual reference uses exact eligible Formal record identity', () async {
    final fixture = await _fixture(latestCardioDays: const [25]);
    final records = await fixture.container.training.findAllRecords();
    final selected = records.singleWhere(
      (record) => record.localDate == '2026-08-22',
    );

    final preparation = await fixture.service.prepare(
      targetRecordId: selected.id,
    );

    expect(preparation.reference?.recordId, selected.id);
    expect(preparation.reference?.operationDate, '2026-08-22');
    expect(preparation.prompt, contains('"referenceMode": "selected"'));
  });

  test('cardio-only manual reference is rejected safely', () async {
    final fixture = await _fixture(latestCardioDays: const [25]);
    final records = await fixture.container.training.findAllRecords();
    final cardio = records.singleWhere(
      (record) => record.localDate == '2026-08-25',
    );

    await expectLater(
      fixture.service.prepare(targetRecordId: cardio.id),
      throwsA(isA<ReportSyncException>()),
    );
  });

  test('unavailable manual reference identity is rejected safely', () async {
    final fixture = await _fixture();

    await expectLater(
      fixture.service.prepare(
        targetRecordId: 'training:00000000-0000-4000-8000-000000000099',
      ),
      throwsA(isA<ReportSyncException>()),
    );
  });

  test('AUTO leaves reference unavailable with cardio-only history', () async {
    final database = FakeIndexedDbDatabase();
    final container = AppRepositoryContainer.indexedDb(database);
    await container.operationState.createInitial(
      OperationLocalDate.parse('2026-08-25'),
    );
    await container.training.saveNewV2(_cardioSession(24));
    final service = TrainingPlanService(
      container: container,
      draftRepository: IndexedDbActiveTrainingDraftRepository(database),
      clock: () => DateTime.utc(2026, 8, 25),
    );

    final preparation = await service.prepare();

    expect(preparation.reference, isNull);
    expect(preparation.referenceCandidates, isEmpty);
    expect(preparation.prompt, contains('"latestStrengthReference": null'));
    expect(preparation.prompt, contains('"comparisons": []'));
  });

  testWidgets('REFERENCE SESSION selects an exact eligible session', (
    tester,
  ) async {
    final fixture = await _fixture(latestCardioDays: const [25]);
    await tester.pumpWidget(
      MaterialApp(home: TrainingPlanImportPage(service: fixture.service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AUTO — LATEST STRENGTH'), findsOneWidget);
    expect(find.textContaining('REFERENCE  2026-08-24'), findsOneWidget);
    expect(find.textContaining('2026-08-25 —'), findsNothing);

    await tester.tap(find.text('AUTO — LATEST STRENGTH'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-08-22 — Bench Press').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('REFERENCE  2026-08-22'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable selected reference can recover to AUTO', (
    tester,
  ) async {
    final fixture = await _fixture();
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingPlanImportPage(
          sourceRecordId: 'training:00000000-0000-4000-8000-000000000099',
          service: fixture.service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('REFERENCE SESSIONを利用できません'), findsOne);
    await tester.tap(find.text('USE AUTO REFERENCE'));
    await tester.pumpAndSettle();

    expect(find.text('AUTO — LATEST STRENGTH'), findsOneWidget);
    expect(find.textContaining('REFERENCE  2026-08-24'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('rejects invalid range and unknown exercise without a draft', () async {
    final fixture = await _fixture();
    final preparation = await fixture.service.prepare(
      targetRecordId: fixture.targetId,
    );
    final invalidRange = _response(
      fixture,
      sourceDigest: preparation.sourceDigest,
      identity: fixture.identity,
      minimum: 10,
      maximum: 8,
    );
    await expectLater(
      fixture.service.preview(
        fixture.container.reportSyncCodec.encode(invalidRange),
      ),
      throwsA(anything),
    );
    final unknown = _response(
      fixture,
      sourceDigest: preparation.sourceDigest,
      identity: 'unknown|none',
    );
    await expectLater(
      fixture.service.preview(
        fixture.container.reportSyncCodec.encode(unknown),
      ),
      throwsA(anything),
    );
    expect(await fixture.drafts.findByOperationDate('2026-08-25'), isNull);
  });

  test(
    'validates explicit rest and training types with legacy compatibility',
    () async {
      final fixture = await _fixture();
      final preparation = await fixture.service.prepare(
        targetRecordId: fixture.targetId,
      );

      final training = await fixture.service.preview(
        fixture.container.reportSyncCodec.encode(
          _response(
            fixture,
            sourceDigest: preparation.sourceDigest,
            identity: fixture.identity,
          ),
        ),
      );
      expect(training.plan.planType, TrainingPlanType.training);

      final legacy = await fixture.service.preview(
        fixture.container.reportSyncCodec.encode(
          _response(
            fixture,
            sourceDigest: preparation.sourceDigest,
            identity: fixture.identity,
            includePlanType: false,
          ),
        ),
      );
      expect(legacy.plan.planType, TrainingPlanType.training);

      final rest = await fixture.service.preview(
        fixture.container.reportSyncCodec.encode(
          _response(
            fixture,
            sourceDigest: preparation.sourceDigest,
            identity: fixture.identity,
            planType: 'rest',
            emptyExercises: true,
            note: '本日は休養を優先する。',
          ),
        ),
      );
      expect(rest.plan.planType, TrainingPlanType.rest);
      expect(rest.plan.exercises, isEmpty);

      for (final invalid in [
        _response(
          fixture,
          sourceDigest: preparation.sourceDigest,
          identity: fixture.identity,
          emptyExercises: true,
        ),
        _response(
          fixture,
          sourceDigest: preparation.sourceDigest,
          identity: fixture.identity,
          planType: 'rest',
        ),
        _response(
          fixture,
          sourceDigest: preparation.sourceDigest,
          identity: fixture.identity,
          includePlanType: false,
          emptyExercises: true,
        ),
        _response(
          fixture,
          sourceDigest: preparation.sourceDigest,
          identity: fixture.identity,
          planType: 'rest',
          emptyExercises: true,
          note: null,
        ),
      ]) {
        await expectLater(
          fixture.service.preview(
            fixture.container.reportSyncCodec.encode(invalid),
          ),
          throwsA(isA<ReportSyncException>()),
        );
      }
    },
  );

  test('rest plan cannot create a draft or formal record', () async {
    final fixture = await _fixture();
    final preparation = await fixture.service.prepare(
      targetRecordId: fixture.targetId,
    );
    final before = await fixture.container.training.findAllRecords();
    final preview = await fixture.service.preview(
      fixture.container.reportSyncCodec.encode(
        _response(
          fixture,
          sourceDigest: preparation.sourceDigest,
          identity: fixture.identity,
          planType: 'rest',
          emptyExercises: true,
          note: '本日は休養を優先する。',
        ),
      ),
    );

    await expectLater(fixture.service.apply(preview), throwsA(anything));
    expect(await fixture.drafts.findByOperationDate('2026-08-25'), isNull);
    expect(
      (await fixture.container.training.findAllRecords()).map(
        (record) => record.id,
      ),
      before.map((record) => record.id),
    );
  });

  test('rejects stale plans and preserves an active recording draft', () async {
    final staleFixture = await _fixture();
    final stalePreparation = await staleFixture.service.prepare(
      targetRecordId: staleFixture.targetId,
    );
    final stalePreview = await staleFixture.service.preview(
      staleFixture.container.reportSyncCodec.encode(
        _response(
          staleFixture,
          sourceDigest: stalePreparation.sourceDigest,
          identity: staleFixture.identity,
        ),
      ),
    );
    await staleFixture.container.training.saveNewV2(
      TrainingSessionV2(
        date: '2026-08-25T08:00:00+09:00',
        exercises: [TrainingExerciseV2(exerciseName: 'Squat', order: 1)],
      ),
    );
    await expectLater(
      staleFixture.service.apply(stalePreview),
      throwsA(anything),
    );
    expect(await staleFixture.drafts.findByOperationDate('2026-08-25'), isNull);

    final activeFixture = await _fixture();
    final activePreparation = await activeFixture.service.prepare(
      targetRecordId: activeFixture.targetId,
    );
    final activePreview = await activeFixture.service.preview(
      activeFixture.container.reportSyncCodec.encode(
        _response(
          activeFixture,
          sourceDigest: activePreparation.sourceDigest,
          identity: activeFixture.identity,
        ),
      ),
    );
    final active = ActiveTrainingDraft(
      operationDate: '2026-08-25',
      startTime: '2026-08-25T10:00:00+09:00',
      entryState: const {
        'sessionName': '',
        'sessionMemo': '',
        'overallEvaluation': '',
        'sessionGrade': null,
        'dynamicStretchCompleted': null,
        'cooldownStretchCompleted': null,
        'exercises': <Object?>[],
        'cardioEntries': <Object?>[],
      },
    );
    await activeFixture.drafts.save(active);
    await expectLater(
      activeFixture.service.apply(activePreview),
      throwsA(anything),
    );
    expect(
      (await activeFixture.drafts.findByOperationDate('2026-08-25'))?.startTime,
      active.startTime,
    );
  });

  for (final width in <double>[320, 390, 900, 1280]) {
    testWidgets(
      'shows a responsive validated plan preview at ${width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = Size(width, 1800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fixture = await _fixture();
        final preparation = await fixture.service.prepare(
          targetRecordId: fixture.targetId,
        );
        final response = _response(
          fixture,
          sourceDigest: preparation.sourceDigest,
          identity: fixture.identity,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: TrainingPlanImportPage(
              sourceRecordId: fixture.targetId,
              service: fixture.service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('PASTE'), findsOneWidget);
        expect(find.text('CLEAR'), findsOneWidget);
        expect(find.text('VALIDATE'), findsOneWidget);
        final paste = find.byKey(
          const ValueKey('report-sync-response-action-paste'),
        );
        final clear = find.byKey(
          const ValueKey('report-sync-response-action-clear'),
        );
        final validate = find.byKey(
          const ValueKey('report-sync-response-action-validate'),
        );
        expect(tester.getTopLeft(paste).dy, tester.getTopLeft(clear).dy);
        expect(tester.getTopLeft(clear).dy, tester.getTopLeft(validate).dy);
        expect(tester.getSize(paste).height, 44);
        expect(tester.getSize(clear).height, 44);
        expect(tester.getSize(validate).height, 44);
        expect(find.byIcon(Icons.content_paste_outlined), findsOneWidget);
        expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
        expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.byType(TextField),
          fixture.container.reportSyncCodec.encode(response),
        );
        await tester.tap(find.text('VALIDATE'));
        await tester.pumpAndSettle();

        expect(find.text('WARM-UP'), findsOneWidget);
        expect(find.text('MAIN'), findsOneWidget);
        expect(find.text('20kg × 8'), findsOneWidget);
        expect(find.text('70kg × 8–10'), findsOneWidget);
        expect(find.text('APPLY PLAN'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in <double>[320, 390, 900, 1280]) {
    testWidgets('shows REST PLAN without APPLY at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = await _fixture();
      final preparation = await fixture.service.prepare(
        targetRecordId: fixture.targetId,
      );
      final response = _response(
        fixture,
        sourceDigest: preparation.sourceDigest,
        identity: fixture.identity,
        planType: 'rest',
        emptyExercises: true,
        note: '本日は休養を優先する。',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainingPlanImportPage(
            sourceRecordId: fixture.targetId,
            service: fixture.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        fixture.container.reportSyncCodec.encode(response),
      );
      await tester.tap(find.text('VALIDATE'));
      await tester.pumpAndSettle();

      expect(find.text('REST PLAN'), findsOneWidget);
      expect(find.text('REST / NO TRAINING'), findsOneWidget);
      expect(find.text('本日は休養を優先する。'), findsOneWidget);
      expect(find.text('OPERATION DATE  2026-08-25'), findsWidgets);
      expect(find.text('BACK TO TRAINING'), findsOneWidget);
      expect(find.text('APPLY PLAN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<_Fixture> _fixture({List<int> latestCardioDays = const []}) async {
  final database = FakeIndexedDbDatabase();
  final container = AppRepositoryContainer.indexedDb(database);
  await container.operationState.createInitial(
    OperationLocalDate.parse('2026-08-25'),
  );
  for (final day in const [18, 19, 20, 21, 22, 23, 24]) {
    await container.training.saveNewV2(_session(day));
  }
  for (final day in latestCardioDays) {
    await container.training.saveNewV2(_cardioSession(day));
  }
  final records = await container.training.findAllRecords();
  final target = records.singleWhere(
    (record) => record.localDate == '2026-08-24',
  );
  final identity = _identity(
    TrainingExerciseIdentity.v2(target.v2Data!.exercises.single),
  );
  final report = TrainingAnalysisReport.initial(
    targetRecordId: target.id,
    operationDate: target.localDate,
    sourceDigest: 'a' * 64,
    responseDigest: 'b' * 64,
    exchangeId: 'analysis-1',
    timestamp: DateTime.utc(2026, 8, 24, 12),
    analysis: TrainingAnalysis(
      sessionSummary: 'Latest analysis',
      performanceAnalysis: 'Performance',
      previousComparison: 'Previous',
      progressAnalysis: 'Progress',
      recoveryFrequencyComment: 'Recovery',
      nextSessionProposal: 'Next',
      riskAttentionNotes: 'Risk',
      exerciseAnalyses: [
        TrainingExerciseAnalysis(
          exerciseIdentity: identity,
          exerciseName: 'Bench Press',
          assessment: 'Assessment',
          previousComparison: 'Previous',
          progress: 'Progress',
          nextProposal: 'Next',
        ),
      ],
    ),
  );
  database.seed(
    IndexedDbStoreNames.trainingAnalysisReportRecords,
    target.id,
    report.toRecord(),
  );
  final drafts = IndexedDbActiveTrainingDraftRepository(database);
  var clockTick = 0;
  return _Fixture(
    container: container,
    drafts: drafts,
    service: TrainingPlanService(
      container: container,
      draftRepository: drafts,
      clock: () => DateTime.utc(
        2026,
        8,
        24,
        12,
      ).add(Duration(microseconds: clockTick++)),
    ),
    targetId: target.id,
    identity: identity,
  );
}

TrainingSessionV2 _session(int day) => TrainingSessionV2(
  date: '2026-08-${day.toString().padLeft(2, '0')}T10:00:00+09:00',
  exercises: [
    TrainingExerciseV2(
      exerciseName: 'Bench Press',
      order: 1,
      sets: [
        TrainingSetV2(
          setNo: 1,
          setType: TrainingSetType.main,
          weightKg: 60 + day.toDouble(),
          reps: 8,
        ),
      ],
    ),
  ],
);

TrainingSessionV2 _cardioSession(int day) => TrainingSessionV2(
  date: '2026-08-${day.toString().padLeft(2, '0')}T10:00:00+09:00',
  cardioEntries: [
    CardioEntryV2(
      purpose: CardioPurpose.main,
      type: CardioType.walking,
      durationSeconds: 1800,
    ),
  ],
);

ReportSyncEnvelope _response(
  _Fixture fixture, {
  required String sourceDigest,
  required String identity,
  int minimum = 8,
  int maximum = 10,
  String planType = 'training',
  bool includePlanType = true,
  bool emptyExercises = false,
  String? note = 'Plan note',
}) => fixture.container.reportSyncCodec.create(
  direction: ReportSyncDirection.response,
  exchangeType: ReportSyncExchangeType.trainingPlan,
  exchangeId: 'training-plan-response-1',
  operationDate: '2026-08-25',
  createdAt: DateTime.utc(2026, 8, 24, 12),
  confirmationDigest: null,
  schemaVersion: ReportSyncEnvelope.importSchemaVersion2,
  payload: {
    'operationDate': '2026-08-25',
    'sourceRecordId': fixture.targetId,
    'sourceDigest': sourceDigest,
    'plan': {
      if (includePlanType) 'planType': planType,
      'note': note,
      'exercises': emptyExercises
          ? <Object?>[]
          : [
              {
                'exerciseIdentity': identity,
                'exerciseName': identity == fixture.identity
                    ? 'Bench Press'
                    : 'Unknown Exercise',
                'sets': [
                  {
                    'order': 1,
                    'setType': 'warmUp',
                    'plannedWeightKg': 20,
                    'targetMinReps': 8,
                    'targetMaxReps': 8,
                    'restAfterSeconds': 60,
                  },
                  {
                    'order': 2,
                    'setType': 'main',
                    'plannedWeightKg': 70,
                    'targetMinReps': minimum,
                    'targetMaxReps': maximum,
                    'restAfterSeconds': 90,
                  },
                ],
              },
            ],
    },
  },
);

String _identity(TrainingExerciseIdentity value) =>
    '${value.exerciseKey}|${value.equipmentKey}';

class _Fixture {
  const _Fixture({
    required this.container,
    required this.drafts,
    required this.service,
    required this.targetId,
    required this.identity,
  });
  final AppRepositoryContainer container;
  final IndexedDbActiveTrainingDraftRepository drafts;
  final TrainingPlanService service;
  final String targetId;
  final String identity;
}
