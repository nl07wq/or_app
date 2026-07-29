import '../../../core/models/cardio_entry_v2.dart';
import '../../../core/models/training_exercise_v2.dart';
import '../../../core/models/training_session_v2.dart';
import '../../../core/models/training_set_v2.dart';
import '../models/training_v2_form_controller.dart';

class TrainingV2FormValidationException implements Exception {
  final String message;

  const TrainingV2FormValidationException(this.message);

  @override
  String toString() => message;
}

abstract final class TrainingV2FormMapper {
  static TrainingSessionV2 toDomain(TrainingV2FormController form) {
    final exercises = <TrainingExerciseV2>[];
    for (final (index, value) in form.exercises.indexed) {
      if (_untouchedExercise(value)) continue;
      final name = value.exerciseName.text.trim();
      if (name.isEmpty) {
        throw const TrainingV2FormValidationException('種目名を入力してください。');
      }
      final sets = <TrainingSetV2>[];
      for (final (setIndex, set) in value.sets.indexed) {
        final weight = _requiredDouble(set.weight.text, '重量');
        final reps = _requiredInt(set.reps.text, '回数');
        if (weight < 0) {
          throw const TrainingV2FormValidationException('重量は0以上で入力してください。');
        }
        if (reps < 1) {
          throw const TrainingV2FormValidationException('回数は1以上で入力してください。');
        }
        final rest = _optionalInt(set.rest.text, 'Rest');
        if (rest != null && rest < 0) {
          throw const TrainingV2FormValidationException('Restは0秒以上で入力してください。');
        }
        if (set.rpe != null && (set.rpe! < 1 || set.rpe! > 10)) {
          throw const TrainingV2FormValidationException('RPEは1から10で入力してください。');
        }
        sets.add(
          TrainingSetV2(
            setNo: setIndex + 1,
            setType: set.setType,
            weightKg: weight,
            reps: reps,
            rpe: set.rpe,
            restAfterSeconds: rest,
          ),
        );
      }
      exercises.add(
        TrainingExerciseV2(
          exerciseName: name,
          order: index + 1,
          equipment: value.equipment,
          sets: sets,
          evaluation: value.evaluation.text,
          nextTarget: _nextTarget(value),
        ),
      );
    }

    final cardio = <CardioEntryV2>[
      for (final value in form.cardioEntries) _cardio(value),
    ];
    if (exercises.isEmpty && cardio.isEmpty) {
      throw const TrainingV2FormValidationException(
        '種目またはCardioを1件以上入力してください。',
      );
    }
    try {
      return TrainingSessionV2(
        date: form.date,
        sessionName: form.sessionName.text,
        sessionGrade: form.sessionGrade,
        memo: form.sessionMemo.text,
        dynamicStretchCompleted: form.dynamicStretchCompleted,
        cooldownStretchCompleted: form.cooldownStretchCompleted,
        overallEvaluation: form.overallEvaluation.text,
        exercises: exercises,
        cardioEntries: cardio,
      );
    } on ArgumentError catch (error) {
      throw TrainingV2FormValidationException('入力内容を確認してください: $error');
    }
  }

  static bool _untouchedExercise(TrainingV2ExerciseFormController value) {
    return value.exerciseName.text.trim().isEmpty &&
        value.evaluation.text.trim().isEmpty &&
        value.equipment == null &&
        value.targetWeight.text.trim().isEmpty &&
        value.targetReps.every((item) => item.text.trim().isEmpty) &&
        value.targetNotes.text.trim().isEmpty &&
        value.sets.every(
          (set) =>
              set.weight.text.trim().isEmpty &&
              set.reps.text.trim().isEmpty &&
              set.rpe == null &&
              set.rest.text.trim().isEmpty,
        );
  }

  static TrainingNextTarget? _nextTarget(
    TrainingV2ExerciseFormController value,
  ) {
    final weight = _optionalDouble(value.targetWeight.text, 'Target Weight');
    if (weight != null && weight < 0) {
      throw const TrainingV2FormValidationException(
        'Target Weightは0以上で入力してください。',
      );
    }
    final reps = <int>[];
    for (final controller in value.targetReps) {
      if (controller.text.trim().isEmpty) continue;
      final parsed = _requiredInt(controller.text, 'Target Reps');
      if (parsed < 1) {
        throw const TrainingV2FormValidationException(
          'Target Repsは1以上で入力してください。',
        );
      }
      reps.add(parsed);
    }
    final notes = value.targetNotes.text.trim();
    if (weight == null && reps.isEmpty && notes.isEmpty) return null;
    return TrainingNextTarget(
      targetWeightKg: weight,
      targetReps: reps,
      notes: notes,
    );
  }

  static CardioEntryV2 _cardio(TrainingV2CardioFormController value) {
    final purpose = value.purpose;
    final type = value.type;
    if (purpose == null) {
      throw const TrainingV2FormValidationException('Cardio Purposeを選択してください。');
    }
    if (type == null) {
      throw const TrainingV2FormValidationException('Cardio Typeを選択してください。');
    }
    final minutes = _optionalInt(value.minutes.text, 'Minutes') ?? 0;
    final seconds = _optionalInt(value.seconds.text, 'Seconds') ?? 0;
    if (minutes < 0 || seconds < 0 || seconds > 59) {
      throw const TrainingV2FormValidationException(
        'Cardio時間の分・秒を正しく入力してください。',
      );
    }
    final durationSeconds = minutes * 60 + seconds;
    if (durationSeconds < 1) {
      throw const TrainingV2FormValidationException('Cardio時間は1秒以上で入力してください。');
    }
    final average = _optionalInt(value.averageHeartRate.text, 'Average HR');
    final maximum = _optionalInt(value.maximumHeartRate.text, 'Maximum HR');
    if (average != null && average < 1 || maximum != null && maximum < 1) {
      throw const TrainingV2FormValidationException('Heart Rateは1以上で入力してください。');
    }
    if (average != null && maximum != null && maximum < average) {
      throw const TrainingV2FormValidationException(
        'Maximum HRはAverage HR以上で入力してください。',
      );
    }
    try {
      return CardioEntryV2(
        purpose: purpose,
        type: type,
        equipment: value.equipment,
        durationSeconds: durationSeconds,
        distanceKm: _optionalDouble(value.distance.text, 'Distance'),
        mets: _optionalDouble(value.mets.text, 'METs'),
        averageHeartRateBpm: average,
        maximumHeartRateBpm: maximum,
        averageSpeedKmh: _optionalDouble(value.averageSpeed.text, 'Speed'),
        estimatedCaloriesKcal: null,
        weightSnapshotKg: null,
        calculationMethod: null,
        calculationVersion: null,
        notes: value.notes.text,
        legacyIntensity: null,
        legacyReferenceCaloriesKcal: null,
      );
    } on ArgumentError catch (error) {
      throw TrainingV2FormValidationException('Cardio入力を確認してください: $error');
    }
  }

  static double _requiredDouble(String source, String label) {
    final value = double.tryParse(source.trim());
    if (value == null || !value.isFinite) {
      throw TrainingV2FormValidationException('$labelを数値で入力してください。');
    }
    return value;
  }

  static double? _optionalDouble(String source, String label) {
    if (source.trim().isEmpty) return null;
    return _requiredDouble(source, label);
  }

  static int _requiredInt(String source, String label) {
    final value = int.tryParse(source.trim());
    if (value == null) {
      throw TrainingV2FormValidationException('$labelを整数で入力してください。');
    }
    return value;
  }

  static int? _optionalInt(String source, String label) {
    if (source.trim().isEmpty) return null;
    return _requiredInt(source, label);
  }
}
