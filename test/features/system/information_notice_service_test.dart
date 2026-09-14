import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/features/system/models/information_notice.dart';
import 'package:or_app/features/system/services/information_notice_service.dart';
import 'package:or_app/features/report_sync/models/morning_brief_record.dart';
import 'package:or_app/features/report_sync/services/daily_brief_plantar_risk_review_service.dart';
import 'package:or_app/features/training_analysis/services/recovery_evidence_shadow_v2_service.dart';

void main() {
  group('InformationNoticeService', () {
    late _MemoryStore store;
    late DateTime now;

    setUp(() {
      store = _MemoryStore();
      now = DateTime(2026, 9, 20, 10);
    });

    test('creates one unread notice for a review-ready transition', () async {
      final service = _service(store, now, [_candidate('v2-beta-1')]);

      final active = await service.activeNotices();

      expect(active, hasLength(1));
      expect(active.single.id, 'recovery-v2-review-ready:v2-beta-1');
      expect(active.single.state, InformationNoticeState.unread);
      expect((await service.activeNotices()), hasLength(1));
      expect((await service.history()), hasLength(1));
    });

    test(
      'read then dismiss keeps an audit record but hides the strip',
      () async {
        final service = _service(store, now, [_candidate('v2-beta-1')]);
        final id = (await service.activeNotices()).single.id;

        await service.markRead(id);
        expect(
          (await service.history()).single.state,
          InformationNoticeState.read,
        );

        await service.dismiss(id);
        expect(await service.activeNotices(), isEmpty);
        final history = await service.history();
        expect(history.single.state, InformationNoticeState.dismissed);
        expect(history.single.dismissedAt, now);
      },
    );

    test(
      'dismissed same-version notice is not regenerated across reload',
      () async {
        final first = _service(store, now, [_candidate('v2-beta-1')]);
        final id = (await first.activeNotices()).single.id;
        await first.dismiss(id);

        final reloaded = _service(store, now, [_candidate('v2-beta-1')]);
        expect(await reloaded.activeNotices(), isEmpty);
        expect((await reloaded.history()), hasLength(1));
      },
    );

    test(
      'a new parameter version creates a distinct notice lifecycle',
      () async {
        final first = _service(store, now, [_candidate('v2-beta-1')]);
        await first.dismiss((await first.activeNotices()).single.id);

        final next = _service(store, now, [_candidate('v2-beta-2')]);
        final active = await next.activeNotices();
        expect(active, hasLength(1));
        expect(active.single.parameterVersion, 'v2-beta-2');
        expect((await next.history()), hasLength(2));
      },
    );

    test(
      'multiple active notices use one deterministic priority order',
      () async {
        final service = _service(store, now, [
          const InformationNoticeCandidate(
            id: 'ordinary',
            priority: InformationNoticePriority.informational,
            category: 'SYSTEM',
            title: 'ORDINARY',
            message: 'ordinary',
            parameterVersion: 'v1',
          ),
          const InformationNoticeCandidate(
            id: 'safety',
            priority: InformationNoticePriority.safety,
            category: 'SYSTEM',
            title: 'SAFETY',
            message: 'safety',
            parameterVersion: 'v1',
          ),
        ]);

        final active = await service.activeNotices();
        expect(active.map((value) => value.title), ['SAFETY', 'ORDINARY']);
      },
    );

    test(
      'debug notices use the production store and persist across reload',
      () async {
        final service = _service(store, now, const []);

        final created = await service.createDebugNotice(
          title: 'INFORMATION TEST',
          message: 'test message',
          priority: InformationNoticePriority.informational,
        );

        expect(created.isDebug, isTrue);
        expect((await service.activeNotices()).single.id, created.id);
        final reloaded = _service(store, now, const []);
        expect(
          (await reloaded.history()).single.provenance,
          InformationNoticeProvenance.debug,
        );
      },
    );

    test(
      'clearing debug notices never removes a real producer notice',
      () async {
        final real = _candidate('v2-beta-1');
        final service = _service(store, now, [real]);
        final realId = (await service.activeNotices()).single.id;
        final debug = await service.createDebugNotice(
          title: 'TEST',
          message: 'test',
          priority: InformationNoticePriority.safety,
        );

        await service.clearDebugNotices();

        final history = await service.history();
        expect(history.map((value) => value.id), contains(realId));
        expect(history.map((value) => value.id), isNot(contains(debug.id)));
        expect((await service.activeNotices()).single.id, realId);
      },
    );

    test('individual debug deletion cannot delete a real notice', () async {
      final real = _candidate('v2-beta-1');
      final service = _service(store, now, [real]);
      final realId = (await service.activeNotices()).single.id;

      await service.deleteDebugNotice(realId);

      expect((await service.history()).single.id, realId);
    });
  });

  test('only Recovery V2 review ready produces the initial candidate', () {
    expect(
      recoveryV2ReviewReadyCandidate(
        RecoveryEvidenceShadowValidationOverall.collecting,
      ),
      isNull,
    );
    expect(
      recoveryV2ReviewReadyCandidate(
        RecoveryEvidenceShadowValidationOverall.firstReviewAvailable,
      ),
      isNull,
    );
    final candidate = recoveryV2ReviewReadyCandidate(
      RecoveryEvidenceShadowValidationOverall.reviewReady,
    );
    expect(candidate?.id, 'recovery-v2-review-ready:v2-beta-1');
  });

  test(
    'Daily Brief V2 review ready is version-aware and only starts at ten',
    () {
      const review = DailyBriefPlantarRiskReviewService();
      final notReady = review.summarize(_briefs(9));
      expect(dailyBriefPlantarRiskReviewReadyCandidate(notReady), isNull);

      final ready = review.summarize(_briefs(10));
      final candidate = dailyBriefPlantarRiskReviewReadyCandidate(ready);
      expect(candidate?.id, 'daily-brief-plantar-review-ready:plantar-risk-v2');
      expect(candidate?.title, 'DAILY BRIEF — REVIEW READY');

      final v3 = review.summarize(
        _briefs(10, version: 'plantar-risk-v3'),
        version: 'plantar-risk-v3',
      );
      expect(
        dailyBriefPlantarRiskReviewReadyCandidate(v3)?.id,
        'daily-brief-plantar-review-ready:plantar-risk-v3',
      );
    },
  );
}

List<MorningBriefRecord> _briefs(
  int count, {
  String version = 'plantar-risk-v2',
}) => [
  for (var index = 0; index < count; index++)
    MorningBriefRecord.v2(
      localDate: '2026-09-${(index + 1).toString().padLeft(2, '0')}',
      sourceType: 'status',
      sourceOperationDate: '2026-09-${(index + 1).toString().padLeft(2, '0')}',
      sourceRecordId: 'status:$index',
      sourceDigest:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      evaluationVersion: version,
      responseDigest:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      exchangeId: 'exchange:$index',
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
      operationStatus: MorningBriefOperationStatus.green,
      commanderIntent: 'intent',
      actions: const [],
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    ),
];

InformationNoticeService _service(
  _MemoryStore store,
  DateTime now,
  List<InformationNoticeCandidate> candidates,
) => InformationNoticeService(
  store: store,
  producers: [_StaticProducer(candidates)],
  now: () => now,
);

InformationNoticeCandidate _candidate(String version) =>
    InformationNoticeCandidate(
      id: 'recovery-v2-review-ready:$version',
      priority: InformationNoticePriority.review,
      category: 'RECOVERY V2 SHADOW',
      title: 'RECOVERY V2 BETA — REVIEW READY',
      message: 'review',
      parameterVersion: version,
      actionLabel: 'SYSTEM MONITORINGを確認',
    );

class _StaticProducer implements InformationNoticeProducer {
  const _StaticProducer(this.candidates);

  final List<InformationNoticeCandidate> candidates;

  @override
  Future<List<InformationNoticeCandidate>> activeCandidates(
    DateTime now,
  ) async => candidates;
}

class _MemoryStore implements InformationNoticeMetadataStore {
  List<InformationNotice> values = [];

  @override
  Future<List<InformationNotice>> load() async => [...values];

  @override
  Future<void> save(List<InformationNotice> notices) async {
    values = [...notices];
  }
}
