import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/widgets/operation_card.dart';
import 'package:or_app/core/models/training_exercise.dart';
import 'package:or_app/core/models/training_session.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/core/models/training_set.dart';
import 'package:or_app/core/models/training_set_v2.dart';
import 'package:or_app/core/models/training_exercise_v2.dart';
import 'package:or_app/core/models/training_equipment_snapshot.dart';
import 'package:or_app/features/training/data_center_training_history_page.dart';
import 'package:or_app/features/training/models/training_record_read_model.dart';
import 'package:or_app/features/training/services/training_history_overview_adapter.dart';
import 'package:or_app/features/training/services/training_history_domain_service.dart';
import 'package:or_app/features/training/services/training_history_range_preference.dart';
import 'package:or_app/features/training/services/training_recovery_evidence_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders overview metrics and charts at narrow widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRAINING HISTORY'), findsWidgets);
    expect(find.text('RECORDED VOLUME'), findsWidgets);
    expect(find.text('STRENGTH OVERVIEW'), findsOneWidget);
    for (final label in [
      '1週間',
      '15日',
      '1か月',
      '3か月',
      '6か月',
      '1年',
      '全期間',
      '指定期間',
    ]) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    expect(find.widgetWithText(ChoiceChip, '概要'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '種目'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'OVERVIEW'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'EXERCISE'), findsNothing);
    expect(find.textContaining('表示期間:'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('月曜開始・週あたりのストレングスセッション数'), 300);
    expect(find.text('月曜開始・週あたりのストレングスセッション数'), findsOneWidget);
    expect(
      find.text('MONDAY START · STRENGTH SESSIONS PER WEEK'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an intentional no-history state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DataCenterTrainingHistoryPage(recordsLoader: _noRecords),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('TRAINING HISTORYはまだありません'), findsOneWidget);
  });

  testWidgets('keeps the summary grid usable at iPhone-class width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('STRENGTH SESSIONS'), findsOneWidget);
    expect(find.text('STRENGTH DAYS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers overview metric value and unit groups', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectOverviewMetricValueCentered(tester, 'STRENGTH SESSIONS', '1');
    _expectOverviewMetricValueCentered(tester, 'STRENGTH DAYS', '1');
    _expectOverviewMetricValueUnitCentered(
      tester,
      'RECORDED VOLUME',
      '500',
      'kg',
    );
    _expectOverviewMetricValueUnitCentered(tester, 'TOTAL REPS', '10', 'reps');
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens exercise weight history and recovery evidence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('種目'));
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT HISTORY'), findsOneWidget);
    expect(find.text('LAST TRAINED'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '回復'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
    await tester.pumpAndSettle();
    expect(find.text('胸'), findsOneWidget);
    expect(find.text('最終実施'), findsOneWidget);
    expect(find.text('2026-08-03'), findsOneWidget);
    expect(find.text('時刻精度'), findsOneWidget);
    expect(find.text('日付のみ'), findsOneWidget);
    expect(find.text('回復基準'), findsOneWidget);
    expect(find.text('48時間'), findsOneWidget);
    expect(find.text('基準回復進行'), findsOneWidget);
    expect(find.textContaining('日付のみ'), findsWidgets);
    expect(find.bySemanticsLabel('胸 算出不可'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a formal exact exposure time in recovery at 390px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(
              startTime: '2026-08-03T20:14:00+09:00',
              exerciseName: 'Lat Pulldown',
              equipment: TrainingEquipmentSnapshot(
                catalogId: 'hammer_strength_lat_pulldown',
                name: 'Hammer Strength Lat Pulldown',
              ),
            ),
          ],
          clock: () => DateTime(2026, 8, 3, 22),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2026-08-03'), findsOneWidget);
    expect(find.text('日付のみ'), findsNothing);
    expect(find.text('回復基準'), findsOneWidget);
    expect(find.text('48時間'), findsOneWidget);
    expect(find.text('基準回復進行'), findsOneWidget);
    expect(find.text('負荷直後'), findsOneWidget);
    expect(find.text('回復目安'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a future formal exposure unavailable without a gauge', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(
              date: '2026-08-04',
              startTime: '2026-08-04T20:14:00+09:00',
            ),
          ],
          clock: () => DateTime(2026, 8, 4, 9),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
    await tester.pumpAndSettle();

    expect(find.text('算出不可'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('基準回復進行 [0-9]+%')), findsNothing);
    expect(find.text('回復目安'), findsNothing);
    expect(find.bySemanticsLabel('胸 算出不可'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the V1-C1 fallback when a policy is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(startTime: '2026-08-03T20:14:00+09:00'),
          ],
          clock: () => DateTime(2026, 8, 3, 22),
          recoveryAdapter: TrainingRecoveryEvidenceAdapter(
            domain: const TrainingHistoryDomainService(
              recoveryPolicy: RecoveryReferencePolicy(referenceDurations: {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
    await tester.pumpAndSettle();

    expect(find.text('未設定'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('基準回復進行 [0-9]+%')), findsNothing);
    expect(find.text('回復目安'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders recovery status badges and gauge fills by progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final start = DateTime.parse('2026-08-03T20:14:00+09:00');
    final cases = [
      (hours: 0, progress: 0.0, status: '負荷直後'),
      (hours: 9.6, progress: 0.2, status: '負荷直後'),
      (hours: 24.0, progress: 0.5, status: '回復中'),
      (hours: 38.4, progress: 0.8, status: '回復目安に接近'),
      (hours: 48.0, progress: 1.0, status: '回復目安到達'),
    ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: DataCenterTrainingHistoryPage(
            recordsLoader: () async => [
              _v2Record(startTime: '2026-08-03T20:14:00+09:00'),
            ],
            clock: () => start.add(
              Duration(milliseconds: (testCase.hours * 3600000).round()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
      await tester.pumpAndSettle();

      final track = tester.getSize(
        find.byKey(const ValueKey('recovery-gauge-track-chest')),
      );
      final fill = tester.getSize(
        find.byKey(const ValueKey('recovery-gauge-fill-chest')),
      );
      expect(fill.width, closeTo(track.width * testCase.progress, 0.1));
      expect(
        find.byKey(const ValueKey('recovery-status-badge-chest')),
        findsOneWidget,
      );
      expect(find.text(testCase.status), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps recovery reference, gauge, and evidence compact at 390px',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: DataCenterTrainingHistoryPage(
            recordsLoader: () async => [
              _v2Record(
                startTime: '2026-08-03T20:14:00+09:00',
                exerciseName: 'Squat',
                equipment: TrainingEquipmentSnapshot(
                  name: 'HAMMER STRENGTH LINEAR LEG PRESS',
                ),
              ),
            ],
            clock: () => DateTime(2026, 8, 4, 20, 14),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
      await tester.pumpAndSettle();

      final reference = tester.getRect(
        find.byKey(const ValueKey('recovery-reference-field')),
      );
      final ready = tester.getRect(
        find.byKey(const ValueKey('recovery-ready-field')),
      );
      expect(reference.top, closeTo(ready.top, 0.1));

      final lastTrained = tester.getRect(
        find.byKey(const ValueKey('recovery-evidence-last-trained')),
      );
      final exercise = tester.getRect(
        find.byKey(const ValueKey('recovery-evidence-exercise')),
      );
      final equipment = tester.getRect(
        find.byKey(const ValueKey('recovery-evidence-equipment')),
      );
      expect(lastTrained.top, lessThan(exercise.top));
      expect(exercise.top, closeTo(equipment.top, 0.1));
      expect(equipment.width / exercise.width, closeTo(1.5, 0.1));
      expect(lastTrained.width, greaterThan(equipment.width));
      expect(equipment.right, lessThanOrEqualTo(390));
      expect(equipment.width, greaterThan(0));
      expect(find.text('HAMMER STRENGTH リニアレッグプレス'), findsOneWidget);
      expect(find.text('72時間'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uses the bounded two-plus-one recovery evidence fallback at 320px',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: DataCenterTrainingHistoryPage(
            recordsLoader: () async => [
              _v2Record(
                startTime: '2026-08-03T20:14:00+09:00',
                exerciseName: 'Lat Pulldown',
                equipment: TrainingEquipmentSnapshot(
                  catalogId: 'hammer_strength_lat_pulldown',
                  name: 'Hammer Strength Lat Pulldown',
                ),
              ),
            ],
            clock: () => DateTime(2026, 8, 4, 20, 14),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
      await tester.pumpAndSettle();

      final lastTrained = tester.getRect(
        find.byKey(const ValueKey('recovery-evidence-last-trained')),
      );
      final exercise = tester.getRect(
        find.byKey(const ValueKey('recovery-evidence-exercise')),
      );
      final equipment = tester.getRect(
        find.byKey(const ValueKey('recovery-evidence-equipment')),
      );
      expect(lastTrained.top, lessThan(exercise.top));
      expect(exercise.top, lessThan(equipment.top));
      expect(equipment.width, greaterThan(exercise.width));
      expect(equipment.right, lessThanOrEqualTo(320));
      _expectNotEllipsized(
        tester,
        find
            .descendant(
              of: find.byKey(const ValueKey('recovery-evidence-equipment')),
              matching: find.byType(Text),
            )
            .at(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('maps recovery status and selection through the body map', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(
              id: 'chest',
              date: '2026-09-08',
              startTime: '2026-09-08T20:00:00+09:00',
            ),
            _v2Record(
              id: 'quadriceps',
              date: '2026-09-09',
              startTime: '2026-09-09T20:00:00+09:00',
              exerciseName: 'Squat',
            ),
          ],
          clock: () => DateTime.parse('2026-09-10T06:00:00+09:00'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('recovery-body-map')), findsOneWidget);
    expect(find.byKey(const ValueKey('body-map-front-canvas')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('body-map-region-front-chest-2')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('上腕二頭筋 データなし'), findsWidgets);
    expect(
      find.byKey(const ValueKey('recovery-card-quadriceps')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('body-map-region-front-chest-2')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recovery-card-chest')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recovery-card-quadriceps')),
      findsNothing,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '背面'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('body-map-back-canvas')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('body-map-region-back-back-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('recovery-card-chest')), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '一覧'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('recovery-body-map')), findsNothing);
    expect(find.byKey(const ValueKey('body-map-back-canvas')), findsNothing);
    expect(find.byKey(const ValueKey('recovery-card-chest')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recovery-card-quadriceps')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, '前面'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('body-map-front-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the body map bounded at narrow and iPhone widths', (
    tester,
  ) async {
    for (final width in [320.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      await tester.pumpWidget(
        MaterialApp(
          home: DataCenterTrainingHistoryPage(
            recordsLoader: () async => [
              _v2Record(
                date: '2026-09-08',
                startTime: '2026-09-08T20:00:00+09:00',
                equipment: TrainingEquipmentSnapshot(
                  name: 'HAMMER STRENGTH LINEAR LEG PRESS',
                ),
              ),
            ],
            clock: () => DateTime.parse('2026-09-09T06:00:00+09:00'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '回復'));
      await tester.pumpAndSettle();

      _expectFindersOneRow(tester, [
        find.widgetWithText(ChoiceChip, '前面'),
        find.widgetWithText(ChoiceChip, '背面'),
        find.widgetWithText(ChoiceChip, '一覧'),
      ]);

      final canvas = tester.getRect(
        find.byKey(const ValueKey('body-map-front-canvas')),
      );
      expect(canvas.width, lessThanOrEqualTo(224));
      expect(canvas.right, lessThanOrEqualTo(width));
      expect(
        find.byKey(const ValueKey('body-map-region-front-chest-2')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('switches exercise metric between weight reps and volume', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('種目'));
    await tester.pumpAndSettle();

    expect(find.text('WEIGHT HISTORY'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'REPS'));
    await tester.pumpAndSettle();
    expect(find.text('LATEST REPS'), findsOneWidget);
    expect(find.text('REPS HISTORY'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'VOLUME'));
    await tester.pumpAndSettle();
    expect(find.text('LATEST RECORDED\nVOLUME'), findsOneWidget);
    expect(find.text('RECORDED VOLUME HISTORY'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'RPE'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'RECORDED'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'WORKING'), findsOneWidget);
    expect(find.text('CHANGE'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Working Volume and RPE only from formal v2 data', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record(), _v2Record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
    await tester.pumpAndSettle();

    final volume = find.widgetWithText(ChoiceChip, 'VOLUME');
    await tester.ensureVisible(volume);
    await tester.tap(volume);
    await tester.pumpAndSettle();
    final working = find.widgetWithText(ChoiceChip, 'WORKING');
    await tester.ensureVisible(working);
    await tester.tap(working);
    await tester.pumpAndSettle();
    expect(find.text('LATEST WORKING\nVOLUME'), findsOneWidget);
    expect(find.text('WORKING VOLUME HISTORY'), findsOneWidget);

    final rpe = find.widgetWithText(ChoiceChip, 'RPE');
    await tester.ensureVisible(rpe);
    await tester.tap(rpe);
    await tester.pumpAndSettle();
    expect(find.text('LATEST RPE'), findsOneWidget);
    expect(find.text('RPE HISTORY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('centers exercise metric value and unit groups', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(id: 'first', date: '2026-08-01', weight: 250, rpe: 8),
            _v2Record(id: 'latest', date: '2026-08-03', weight: 260, rpe: 9),
          ],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
    await tester.pumpAndSettle();

    for (final id in [
      'latest-summary',
      'max-summary',
      'latest-comparison',
      'previous-comparison',
      'change-comparison',
    ]) {
      _expectInlineMetricValueUnit(tester, id, 'kg');
    }

    await tester.tap(find.widgetWithText(ChoiceChip, 'REPS'));
    await tester.pumpAndSettle();
    for (final id in [
      'latest-summary',
      'max-summary',
      'latest-comparison',
      'previous-comparison',
      'change-comparison',
    ]) {
      _expectInlineMetricValueUnit(tester, id, 'reps');
    }

    await tester.tap(find.widgetWithText(ChoiceChip, 'VOLUME'));
    await tester.pumpAndSettle();
    expect(find.text('LATEST RECORDED\nVOLUME'), findsOneWidget);
    expect(find.text('MAX RECORDED\nVOLUME'), findsOneWidget);
    for (final (id, unit) in [
      ('latest-summary', 't'),
      ('max-summary', 't'),
      ('latest-comparison', 't'),
      ('previous-comparison', 't'),
      ('change-comparison', 'kg'),
    ]) {
      _expectInlineMetricValueUnit(tester, id, unit);
    }

    await tester.tap(find.widgetWithText(ChoiceChip, 'WORKING'));
    await tester.pumpAndSettle();
    expect(find.text('LATEST WORKING\nVOLUME'), findsOneWidget);
    expect(find.text('MAX WORKING\nVOLUME'), findsOneWidget);
    for (final (id, unit) in [
      ('latest-summary', 't'),
      ('max-summary', 't'),
      ('latest-comparison', 't'),
      ('previous-comparison', 't'),
      ('change-comparison', 'kg'),
    ]) {
      _expectInlineMetricValueUnit(tester, id, unit);
    }

    await tester.tap(find.widgetWithText(ChoiceChip, 'RPE'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('metric-unit-latest-summary')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('metric-unit-latest-comparison')),
      findsNothing,
    );
    _expectMetricValueCentered(tester, 'last-trained');
    _expectMetricValueCentered(tester, 'latest-summary');
    _expectMetricValueCentered(tester, 'latest-comparison');
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the latest two available points for comparison', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(id: 'first', date: '2026-08-01', weight: 60, rpe: 8),
            _v2Record(id: 'latest', date: '2026-08-03', weight: 70, rpe: 9),
          ],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
    await tester.pumpAndSettle();

    expect(find.text('PREVIOUS'), findsOneWidget);
    expect(find.text('CHANGE'), findsOneWidget);
    expect(find.text('+10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skips missing RPE observations when comparing sessions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(id: 'first', date: '2026-08-01', rpe: 8),
            _v2Record(id: 'missing', date: '2026-08-02', rpe: null),
            _v2Record(id: 'latest', date: '2026-08-03', rpe: 9),
          ],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
    await tester.pumpAndSettle();
    final rpe = find.widgetWithText(ChoiceChip, 'RPE');
    await tester.ensureVisible(rpe);
    await tester.tap(rpe);
    await tester.pumpAndSettle();

    expect(find.text('PREVIOUS'), findsOneWidget);
    expect(find.text('+1.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps v1 Working Volume and RPE intentionally unavailable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'VOLUME'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'WORKING'));
    await tester.pumpAndSettle();
    expect(find.text('WORKING VOLUME DATA NOT AVAILABLE'), findsOneWidget);
    expect(
      find.text('Working-set classification is not recorded for this history.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'RPE'));
    await tester.pumpAndSettle();
    expect(find.text('RPE DATA NOT AVAILABLE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps all exercise metrics usable at 320px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('種目'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ChoiceChip, 'WEIGHT'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'REPS'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'VOLUME'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'RPE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps exercise analytics controls and cards compact at 390px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [
            _v2Record(id: 'first', date: '2026-08-01', weight: 60),
            _v2Record(id: 'latest', date: '2026-08-03', weight: 80),
          ],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
    await tester.pumpAndSettle();

    _expectOneRow(tester, [
      find.widgetWithText(ChoiceChip, 'WEIGHT'),
      find.widgetWithText(ChoiceChip, 'REPS'),
      find.widgetWithText(ChoiceChip, 'VOLUME'),
      find.widgetWithText(ChoiceChip, 'RPE'),
    ]);

    await tester.tap(find.widgetWithText(ChoiceChip, 'VOLUME'));
    await tester.pumpAndSettle();
    _expectOneRow(tester, [
      find.widgetWithText(ChoiceChip, 'RECORDED'),
      find.widgetWithText(ChoiceChip, 'WORKING'),
    ]);
    _expectOneRow(tester, [
      find.text('LAST TRAINED'),
      find.text('LATEST RECORDED\nVOLUME'),
      find.text('MAX RECORDED\nVOLUME'),
    ]);
    _expectOneRow(tester, [
      find.text('LATEST'),
      find.text('PREVIOUS'),
      find.text('CHANGE'),
    ]);

    await tester.tap(find.widgetWithText(ChoiceChip, 'WORKING'));
    await tester.pumpAndSettle();
    _expectOneRow(tester, [
      find.text('LAST TRAINED'),
      find.text('LATEST WORKING\nVOLUME'),
      find.text('MAX WORKING\nVOLUME'),
    ]);
    _expectOneRow(tester, [
      find.text('LATEST'),
      find.text('PREVIOUS'),
      find.text('CHANGE'),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps long exercise summary labels in compact columns at 320px',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: DataCenterTrainingHistoryPage(
            recordsLoader: () async => [
              _v2Record(id: 'first', date: '2026-08-01', weight: 60),
              _v2Record(id: 'latest', date: '2026-08-03', weight: 80),
            ],
            clock: () => DateTime(2026, 8, 3),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'VOLUME'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'WORKING'));
      await tester.pumpAndSettle();

      _expectOneRow(tester, [
        find.widgetWithText(ChoiceChip, 'WEIGHT'),
        find.widgetWithText(ChoiceChip, 'REPS'),
        find.widgetWithText(ChoiceChip, 'VOLUME'),
        find.widgetWithText(ChoiceChip, 'RPE'),
      ]);
      _expectOneRow(tester, [
        find.widgetWithText(ChoiceChip, 'RECORDED'),
        find.widgetWithText(ChoiceChip, 'WORKING'),
      ]);
      _expectOneRow(tester, [
        find.text('LAST TRAINED'),
        find.text('LATEST WORKING\nVOLUME'),
        find.text('MAX WORKING\nVOLUME'),
      ]);
      _expectNotEllipsized(tester, find.text('LATEST WORKING\nVOLUME'));
      _expectNotEllipsized(tester, find.text('MAX WORKING\nVOLUME'));
      for (final id in [
        'latest-summary',
        'max-summary',
        'latest-comparison',
        'previous-comparison',
        'change-comparison',
      ]) {
        _expectInlineMetricValueUnit(tester, id, 'kg');
      }
      _expectOneRow(tester, [
        find.text('LATEST'),
        find.text('PREVIOUS'),
        find.text('CHANGE'),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('presents equipment as readable selector metadata', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => _recordsWithEquipment(),
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('種目'));
    await tester.pumpAndSettle();

    expect(find.text('種目'), findsOneWidget);
    expect(find.text('EQUIPMENT'), findsOneWidget);
    expect(find.text('ベンチプレス'), findsOneWidget);
    expect(find.text('ダンベル'), findsOneWidget);
    expect(find.textContaining('hammer_strength'), findsNothing);
    await tester.tap(find.byKey(const Key('exercise-equipment-selector')));
    await tester.pumpAndSettle();

    expect(find.text('ALL EQUIPMENT'), findsOneWidget);
    expect(find.text('HAMMER STRENGTH パワーラック'), findsOneWidget);
    expect(find.text('EQUIPMENT NOT RECORDED'), findsOneWidget);
    await tester.tap(find.text('HAMMER STRENGTH パワーラック'));
    await tester.pumpAndSettle();
    expect(find.text('WEIGHT HISTORY'), findsOneWidget);
    expect(find.text('HAMMER STRENGTH パワーラック'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exercise-equipment-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALL EQUIPMENT'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'SELECT EQUIPMENT TO VIEW WEIGHT, REPS, VOLUME, OR RPE HISTORY',
      ),
      findsOneWidget,
    );
    expect(find.text('WEIGHT HISTORY'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps two-line exercise selector usable at 320px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => _recordsWithEquipment(),
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('種目'));
    await tester.pumpAndSettle();

    expect(find.text('ベンチプレス'), findsOneWidget);
    expect(find.text('ダンベル'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides all equipment when a category has one variant', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '種目'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exercise-equipment-selector')));
    await tester.pumpAndSettle();

    expect(find.text('ALL EQUIPMENT'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restores the Training-specific period without affecting Body History',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final rangePreference = TrainingHistoryRangePreference(
        preferencesLoader: () async => preferences,
      );
      await rangePreference.save(TrainingHistoryOverviewPeriod.threeMonths);

      await tester.pumpWidget(
        MaterialApp(
          home: DataCenterTrainingHistoryPage(
            recordsLoader: () async => [_record()],
            clock: () => DateTime(2026, 8, 3),
            rangePreference: rangePreference,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, '3か月'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '3か月'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens and cancels the shared-style custom range flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DataCenterTrainingHistoryPage(
          recordsLoader: () async => [_record()],
          clock: () => DateTime(2026, 8, 3),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, '指定期間'));
    await tester.pumpAndSettle();
    expect(find.text('SELECT TRAINING HISTORY RANGE'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<List<TrainingRecordReadModel>> _noRecords() async => const [];

void _expectOneRow(WidgetTester tester, List<Finder> finders) {
  final rects = [
    for (final finder in finders)
      tester.getRect(
        find.ancestor(of: finder, matching: find.byType(OperationCard)),
      ),
  ];
  for (final rect in rects) {
    expect(rect.right, lessThanOrEqualTo(tester.view.physicalSize.width));
    expect(rect.top, closeTo(rects.first.top, 0.1));
  }
}

void _expectFindersOneRow(WidgetTester tester, List<Finder> finders) {
  final rects = [for (final finder in finders) tester.getRect(finder)];
  for (final rect in rects) {
    expect(rect.right, lessThanOrEqualTo(tester.view.physicalSize.width));
    expect(rect.top, closeTo(rects.first.top, 0.1));
  }
}

void _expectNotEllipsized(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
}

void _expectInlineMetricValueUnit(
  WidgetTester tester,
  String id,
  String expectedUnit,
) {
  final value = find.byKey(ValueKey('metric-value-$id'));
  final unit = find.byKey(ValueKey('metric-unit-$id'));
  final card = find.ancestor(of: value, matching: find.byType(OperationCard));
  final valueRect = tester.getRect(value);
  final unitRect = tester.getRect(unit);
  final cardRect = tester.getRect(card);
  expect(tester.widget<Text>(unit).data, expectedUnit);
  expect(valueRect.left, lessThan(unitRect.left));
  expect(unitRect.left - valueRect.right, greaterThan(0));
  expect(unitRect.left - valueRect.right, lessThanOrEqualTo(4));
  expect((valueRect.center.dy - unitRect.center.dy).abs(), lessThan(8));
  expect((valueRect.left + unitRect.right) / 2, closeTo(cardRect.center.dx, 2));
  expect(unitRect.right, lessThanOrEqualTo(cardRect.right));
}

void _expectMetricValueCentered(WidgetTester tester, String id) {
  final value = find.byKey(ValueKey('metric-value-$id'));
  final card = find.ancestor(of: value, matching: find.byType(OperationCard));
  expect(
    tester.getRect(value).center.dx,
    closeTo(tester.getRect(card).center.dx, 0.1),
  );
}

void _expectOverviewMetricValueUnitCentered(
  WidgetTester tester,
  String label,
  String value,
  String unit,
) {
  final card = find.ancestor(
    of: find.text(label),
    matching: find.byType(OperationCard),
  );
  final valueFinder = find.descendant(of: card, matching: find.text(value));
  final unitFinder = find.descendant(of: card, matching: find.text(unit));
  final valueRect = tester.getRect(valueFinder);
  final unitRect = tester.getRect(unitFinder);
  final cardRect = tester.getRect(card);
  expect(unitRect.left - valueRect.right, greaterThan(0));
  expect(unitRect.left - valueRect.right, lessThanOrEqualTo(4));
  expect((valueRect.left + unitRect.right) / 2, closeTo(cardRect.center.dx, 2));
}

void _expectOverviewMetricValueCentered(
  WidgetTester tester,
  String label,
  String value,
) {
  final card = find.ancestor(
    of: find.text(label),
    matching: find.byType(OperationCard),
  );
  final valueFinder = find.descendant(of: card, matching: find.text(value));
  expect(
    tester.getRect(valueFinder).center.dx,
    closeTo(tester.getRect(card).center.dx, 0.1),
  );
}

TrainingRecordReadModel _record() => TrainingRecordReadModel.v1(
  id: 'record',
  localDate: '2026-08-03',
  createdAt: DateTime.utc(2026, 8, 3),
  updatedAt: DateTime.utc(2026, 8, 3),
  data: TrainingSession(
    date: '2026-08-03T00:00:00.000',
    memo: '',
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        order: 1,
        sets: [const TrainingSet(setNo: 1, weight: 50, reps: 10)],
      ),
    ],
  ),
);

List<TrainingRecordReadModel> _recordsWithEquipment() => [
  _recordWithEquipment(
    id: 'rack',
    date: '2026-08-02',
    equipmentId: 'hammer_strength_power_rack',
    weight: 50,
  ),
  _recordWithEquipment(
    id: 'dumbbells',
    date: '2026-08-03',
    equipmentId: 'dumbbells',
    weight: 20,
  ),
  _recordWithEquipment(
    id: 'unrecorded',
    date: '2026-08-01',
    equipmentId: null,
    weight: 40,
  ),
];

TrainingRecordReadModel _recordWithEquipment({
  required String id,
  required String date,
  required String? equipmentId,
  required double weight,
}) => TrainingRecordReadModel.v1(
  id: id,
  localDate: date,
  createdAt: DateTime.parse('${date}T00:00:00Z'),
  updatedAt: DateTime.parse('${date}T00:00:00Z'),
  data: TrainingSession(
    date: '${date}T00:00:00.000',
    memo: '',
    exercises: [
      TrainingExercise(
        exerciseName: 'Bench Press',
        equipmentId: equipmentId,
        order: 1,
        sets: [TrainingSet(setNo: 1, weight: weight, reps: 10)],
      ),
    ],
  ),
);

TrainingRecordReadModel _v2Record({
  String id = 'v2',
  String date = '2026-08-03',
  double weight = 80,
  int? rpe = 8,
  String? startTime,
  String exerciseName = 'Bench Press',
  TrainingEquipmentSnapshot? equipment,
}) => TrainingRecordReadModel.v2(
  id: id,
  localDate: date,
  createdAt: DateTime.parse('${date}T00:00:00Z'),
  updatedAt: DateTime.parse('${date}T00:00:00Z'),
  data: TrainingSessionV2(
    date: '${date}T00:00:00.000',
    startTime: startTime,
    exercises: [
      TrainingExerciseV2(
        exerciseName: exerciseName,
        order: 1,
        equipment: equipment,
        sets: [
          TrainingSetV2(
            setNo: 1,
            setType: TrainingSetType.warmUp,
            weightKg: 40,
            reps: 5,
          ),
          TrainingSetV2(
            setNo: 2,
            setType: TrainingSetType.main,
            weightKg: weight,
            reps: 10,
            rpe: rpe,
          ),
        ],
      ),
    ],
  ),
);
