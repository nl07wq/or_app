import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:or_app/core/models/cardio_entry.dart';
import 'package:or_app/core/models/cardio_entry_v2.dart';
import 'package:or_app/core/models/training_session_v2.dart';
import 'package:or_app/features/training/models/training_v2_form_controller.dart';
import 'package:or_app/features/training/services/training_cardio_calorie_calculator.dart';
import 'package:or_app/features/training/services/training_energy_service.dart';
import 'package:or_app/features/training/services/training_strength_calorie_calculator.dart';
import 'package:or_app/features/training/widgets/training_session_v2_form.dart';

void main() {
  test(
    'calculates session duration, strength duration, and formal calories',
    () {
      final session = _timedSession(cardio: _cardio());
      final result = TrainingStrengthCalorieCalculator.calculate(
        session: session,
        weightKg: 100,
      );

      expect(session.sessionDuration, const Duration(hours: 2));
      expect(session.strengthDuration, const Duration(minutes: 90));
      expect(result.estimatedCaloriesKcal, closeTo(551.25, 1e-12));
      expect(result.weightSnapshotKg, 100);
      expect(result.calculationMethod, 'strengthSessionMetsAcsmV1');
      expect(result.calculationVersion, 1);
    },
  );

  test('keeps missing times uncomputed and supports date crossing', () {
    expect(
      TrainingStrengthCalorieCalculator.calculate(
        session: TrainingSessionV2(date: '2026-08-11'),
        weightKg: 100,
      ).estimatedCaloriesKcal,
      isNull,
    );
    final crossing = TrainingSessionV2(
      date: '2026-08-11',
      startTime: '2026-08-11T23:30:00+09:00',
      endTime: '2026-08-12T00:30:00+09:00',
    );
    expect(crossing.sessionDuration, const Duration(hours: 1));
  });

  test('rejects non-increasing instants and excessive cardio duration', () {
    expect(
      () => TrainingSessionV2(
        date: '2026-08-11',
        startTime: '2026-08-11T10:00:00+09:00',
        endTime: '2026-08-11T10:00:00+09:00',
      ),
      throwsArgumentError,
    );
    expect(
      () => TrainingSessionV2(
        date: '2026-08-11',
        startTime: '2026-08-11T10:00:00+09:00',
        endTime: '2026-08-11T10:10:00+09:00',
        cardioEntries: [_cardio(durationSeconds: 601)],
      ),
      throwsArgumentError,
    );
  });

  test('persists a strength snapshot and derives total with formal cardio', () {
    final cardio = _cardio();
    final saved = TrainingEnergyService.applyForSave(
      session: _timedSession(cardio: cardio),
      statusWeightKg: 100,
    );
    final cardioCalories = TrainingCardioCalorieCalculator.calculate(
      mets: 4,
      durationSeconds: 1800,
      weightKg: 100,
    ).estimatedCaloriesKcal!;

    expect(saved.estimatedStrengthCaloriesKcal, closeTo(551.25, 1e-12));
    expect(
      TrainingEnergyService.totalForSession(saved),
      closeTo(551.25 + cardioCalories, 1e-12),
    );
    final restored = TrainingSessionV2.fromJson(saved.toJson());
    expect(restored.startTime, saved.startTime);
    expect(restored.endTime, saved.endTime);
    expect(
      restored.estimatedStrengthCaloriesKcal,
      saved.estimatedStrengthCaloriesKcal,
    );
  });

  testWidgets('records times only through explicit start and end actions', (
    tester,
  ) async {
    final controller = TrainingV2FormController.newSession(
      localDate: '2026-08-11',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TrainingSessionV2Form(
              controller: controller,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    );

    expect(controller.startTime, isNull);
    expect(controller.endTime, isNull);
    await tester.tap(find.text('START TRAINING'));
    await tester.pump();
    expect(controller.startTime, isNotNull);
    expect(controller.endTime, isNull);
    await tester.tap(find.text('END TRAINING'));
    await tester.pump();
    expect(controller.endTime, isNotNull);
  });
}

TrainingSessionV2 _timedSession({CardioEntryV2? cardio}) => TrainingSessionV2(
  date: '2026-08-11',
  startTime: '2026-08-11T10:00:00+09:00',
  endTime: '2026-08-11T12:00:00+09:00',
  cardioEntries: [if (cardio != null) cardio],
);

CardioEntryV2 _cardio({int durationSeconds = 1800}) => CardioEntryV2(
  purpose: CardioPurpose.main,
  type: CardioType.exerciseBike,
  durationSeconds: durationSeconds,
  mets: 4,
);
